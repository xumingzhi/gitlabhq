require 'addressable/uri'

class Projects::CompareController < Projects::ApplicationController
  include DiffForPath
  include DiffHelper

  # Authorize
  before_action :require_non_empty_project
  before_action :authorize_download_code!
  before_action :define_ref_vars, only: [:index, :show, :diff_for_path]
  before_action :define_diff_vars, only: [:show, :diff_for_path]
  before_action :merge_request, only: [:index, :show]

  def index
  end

  def show
    apply_diff_view_cookie!
  end

  def diff_for_path
    return render_404 unless @compare

    render_diff_for_path(@compare.diffs(diff_options))
  end

  def create
    if params[:from].blank? || params[:to].blank?
      flash[:alert] = "You must select from and to branches"
      from_to_vars = {
        from: params[:from].presence,
        to: params[:to].presence
      }
      redirect_to namespace_project_compare_index_path(@project.namespace, @project, from_to_vars)
    else
      redirect_to namespace_project_compare_path(@project.namespace, @project,
                                               params[:from], params[:to])
    end
  end

  private

  def define_ref_vars
    @start_ref = Addressable::URI.unescape(params[:from])
    @ref = @head_ref = Addressable::URI.unescape(params[:to])
  end

  def define_diff_vars
    @compare = CompareService.new.execute(@project, @head_ref, @project, @start_ref)

    if @compare
      @commits = @compare.commits
      @start_commit = @compare.start_commit
      @commit = @compare.commit
      @base_commit = @compare.base_commit

      @diffs = @compare.diffs(diff_options)

      @diff_notes_disabled = true
      @grouped_diff_discussions = {}
    end
  end

  def merge_request
    @merge_request ||= MergeRequestsFinder.new(current_user, project_id: @project.id).execute.opened.
      find_by(source_project: @project, source_branch: @head_ref, target_branch: @start_ref)
  end
end
