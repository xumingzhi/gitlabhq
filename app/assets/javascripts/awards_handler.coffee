class @AwardsHandler

  constructor: ->

    @aliases = emojiAliases()

    $(document)
      .off 'click', '.js-add-award'
      .on  'click', '.js-add-award', (e) =>
        e.stopPropagation()
        e.preventDefault()

        @showEmojiMenu $(e.currentTarget)

    $('html').on 'click', (e) ->
      $target = $ e.target

      unless $target.closest('.emoji-menu-content').length
        $('.js-awards-block.current').removeClass 'current'

      unless $target.closest('.emoji-menu').length
        if $('.emoji-menu').is(':visible')
          $('.js-add-award.is-active').removeClass 'is-active'
          $('.emoji-menu').removeClass 'is-visible'

    $(document)
      .off 'click', '.js-emoji-btn'
      .on  'click', '.js-emoji-btn', (e) =>
        e.preventDefault()

        $target = $ e.currentTarget
        emoji   = $target.find('.icon').data 'emoji'

        $target.closest('.js-awards-block').addClass 'current'
        @addAward @getAwardUrl(), emoji


  showEmojiMenu: ($addBtn) ->

    $menu = $ '.emoji-menu'

    if $addBtn.hasClass 'note-emoji-button'
      $addBtn.parents('.note').find('.js-awards-block').addClass 'current'
    else
      $addBtn.closest('.js-awards-block').addClass 'current'

    if $menu.length
      $holder = $addBtn.closest('.js-award-holder')

      if $menu.is '.is-visible'
        $addBtn.removeClass 'is-active'
        $menu.removeClass 'is-visible'
        $('#emoji_search').blur()
      else
        $addBtn.addClass 'is-active'
        @positionMenu($menu, $addBtn)

        $menu.addClass 'is-visible'
        $('#emoji_search').focus()
    else
      $addBtn.addClass 'is-loading is-active'
      url = @getAwardMenuUrl()

      @createEmojiMenu url, =>
        $addBtn.removeClass 'is-loading'
        $menu = $('.emoji-menu')
        @positionMenu($menu, $addBtn)
        @renderFrequentlyUsedBlock()

        setTimeout =>
          $menu.addClass 'is-visible'
          $('#emoji_search').focus()
          @setupSearch()
        , 200


  createEmojiMenu: (awardMenuUrl, callback) ->

    $.get awardMenuUrl, (response) ->
      $('body').append response
      callback()


  positionMenu: ($menu, $addBtn) ->

    position = $addBtn.data('position')

    # The menu could potentially be off-screen or in a hidden overflow element
    # So we position the element absolute in the body
    css =
      top: "#{$addBtn.offset().top + $addBtn.outerHeight()}px"

    if position? and position is 'right'
      css.left = "#{($addBtn.offset().left - $menu.outerWidth()) + 20}px"
      $menu.addClass 'is-aligned-right'
    else
      css.left = "#{$addBtn.offset().left}px"
      $menu.removeClass 'is-aligned-right'

    $menu.css(css)


  addAward: (awardUrl, emoji, checkMutuality = yes) ->

    emoji = @normilizeEmojiName emoji

    @postEmoji awardUrl, emoji, =>
      @addAwardToEmojiBar emoji, checkMutuality

    $('.emoji-menu').removeClass 'is-visible'


  addAwardToEmojiBar: (emoji, checkForMutuality = yes) ->

    @checkMutuality emoji  if checkForMutuality
    @addEmojiToFrequentlyUsedList(emoji)

    emoji     = @normilizeEmojiName(emoji)
    $emojiBtn = @findEmojiIcon(emoji).parent()

    if $emojiBtn.length > 0
      if @isActive $emojiBtn
        @decrementCounter $emojiBtn, emoji
      else
        counter = $emojiBtn.find '.js-counter'
        counter.text parseInt(counter.text()) + 1
        $emojiBtn.addClass 'active'
        @addMeToUserList emoji
    else
      @getVotesBlock().removeClass 'hidden'
      @createEmoji emoji


  getVotesBlock: -> return $ '.js-awards-block.current'


  getAwardUrl: -> return @getVotesBlock().data 'award-url'


  checkMutuality: (emoji) ->

    awardUrl = @getAwardUrl()

    if emoji in [ 'thumbsup', 'thumbsdown' ]
      mutualVote = if emoji is 'thumbsup' then 'thumbsdown' else 'thumbsup'
      selector   = "[data-emoji=#{mutualVote}]"

      isAlreadyVoted = @getVotesBlock().find(selector).parent().hasClass 'active'
      @addAward awardUrl, mutualVote, no if isAlreadyVoted


  isActive: ($emojiBtn) -> $emojiBtn.hasClass 'active'


  decrementCounter: ($emojiBtn, emoji) ->

    counter       = $('.js-counter', $emojiBtn)
    counterNumber = parseInt(counter.text())

    if counterNumber > 1
      counter.text(counterNumber - 1)
      @removeMeFromUserList($emojiBtn, emoji)
    else if emoji is 'thumbsup' or emoji is 'thumbsdown'
      $emojiBtn.tooltip('destroy')
      counter.text('0')
      @removeMeFromUserList($emojiBtn, emoji)
      @removeEmoji $emojiBtn if $emojiBtn.parents('.note').length
    else
      @removeEmoji $emojiBtn

    $emojiBtn.removeClass('active')


  removeEmoji: ($emojiBtn) ->

    $emojiBtn.tooltip('destroy')
    $emojiBtn.remove()

    $votesBlock = @getVotesBlock()

    if $votesBlock.find('.js-emoji-btn').length is 0
      $votesBlock.addClass 'hidden'


  getAwardTooltip: ($awardBlock) ->

    return $awardBlock.attr('data-original-title') or $awardBlock.attr('data-title')


  removeMeFromUserList: ($emojiBtn, emoji) ->

    awardBlock    = $emojiBtn
    originalTitle = @getAwardTooltip awardBlock

    authors = originalTitle.split ', '
    authors.splice authors.indexOf('me'), 1

    newAuthors = authors.join ', '

    awardBlock
      .closest '.js-emoji-btn'
      .removeData 'original-title'
      .removeData 'title'
      .attr 'data-original-title', newAuthors
      .attr 'data-title', newAuthors

    @resetTooltip(awardBlock)


  addMeToUserList: (emoji) ->

    awardBlock = @findEmojiIcon(emoji).parent()
    origTitle  = @getAwardTooltip awardBlock
    users      = []

    if origTitle
      users = origTitle.trim().split(', ')

    users.push('me')
    awardBlock.attr('title', users.join(', '))

    @resetTooltip(awardBlock)


  resetTooltip: (award) ->
    award.tooltip('destroy')

    # 'destroy' call is asynchronous and there is no appropriate callback on it, this is why we need to set timeout.
    setTimeout (->
      award.tooltip()
    ), 200


  createEmoji_: (emoji) ->

    emojiCssClass = @resolveNameToCssClass emoji

    buttonHtml = "<button class='btn award-control js-emoji-btn has-tooltip active' title='me' data-placement='bottom'>
      <div class='icon emoji-icon #{emojiCssClass}' data-emoji='#{emoji}'></div>
      <span class='award-control-text js-counter'>1</span>
    </button>"

    emoji_node = $(buttonHtml)
      .insertBefore '.js-awards-block.current .js-award-holder:not(.js-award-action-btn)'
      .find '.emoji-icon'
      .data 'emoji', emoji

    $('.award-control').tooltip()
    $('.js-awards-block.current').removeClass 'current'


  createEmoji: (emoji) ->

    return @createEmoji_ emoji if $('.emoji-menu').length

    @createEmojiMenu @getAwardMenuUrl(), => @createEmoji emoji


  getAwardMenuUrl: -> return gl.awardMenuUrl or '/emojis'


  resolveNameToCssClass: (emoji) ->

    emoji_icon = $(".emoji-menu-content [data-emoji='#{emoji}']")

    if emoji_icon.length > 0
      unicodeName = emoji_icon.data('unicode-name')
    else
      # Find by alias
      unicodeName = $(".emoji-menu-content [data-aliases*=':#{emoji}:']").data('unicode-name')

    return "emoji-#{unicodeName}"


  postEmoji: (awardUrl, emoji, callback) ->

    $.post awardUrl, { name: emoji }, (data) ->
      callback.call() if data.ok


  findEmojiIcon: (emoji) ->

    return $(".js-awards-block.current > .js-emoji-btn [data-emoji='#{emoji}']")


  scrollToAwards: ->

    options = scrollTop: $('.awards').offset().top - 80
    $('body, html').animate options, 200


  normilizeEmojiName: (emoji) -> return @aliases[emoji] or emoji


  addEmojiToFrequentlyUsedList: (emoji) ->

    frequentlyUsedEmojis = @getFrequentlyUsedEmojis()
    frequentlyUsedEmojis.push emoji
    $.cookie 'frequently_used_emojis', frequentlyUsedEmojis.join(','), { expires: 365 }


  getFrequentlyUsedEmojis: ->

    frequentlyUsedEmojis = ($.cookie('frequently_used_emojis') or '').split(',')
    return _.compact _.uniq frequentlyUsedEmojis


  renderFrequentlyUsedBlock: ->

    if $.cookie 'frequently_used_emojis'
      frequentlyUsedEmojis = @getFrequentlyUsedEmojis()

      ul = $("<ul class='clearfix emoji-menu-list'>")

      for emoji in frequentlyUsedEmojis
        $(".emoji-menu-content [data-emoji='#{emoji}']").closest('li').clone().appendTo(ul)

      $('input.emoji-search').after(ul).after($('<h5>').text('Frequently used'))


  setupSearch: ->

    $('input.emoji-search').on 'keyup', (ev) =>
      term = $(ev.target).val()

      # Clean previous search results
      $('ul.emoji-menu-search, h5.emoji-search').remove()

      if term
        # Generate a search result block
        h5 = $('<h5>').text('Search results').addClass('emoji-search')
        found_emojis = @searchEmojis(term).show()
        ul = $('<ul>').addClass('emoji-menu-list emoji-menu-search').append(found_emojis)
        $('.emoji-menu-content ul, .emoji-menu-content h5').hide()
        $('.emoji-menu-content').append(h5).append(ul)
      else
        $('.emoji-menu-content').children().show()


  searchEmojis: (term) ->

    $(".emoji-menu-content [data-emoji*='#{term}']").closest('li').clone()
