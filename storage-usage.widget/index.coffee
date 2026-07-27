command: "BLOCKSIZE=1000000 df -l"

# Enable or disable this widget.
widgetEnabled: true   # true | false

refreshFrequency: '1s'

# Toggle the graph panel on/off without removing the widget
showGraph: false

# choose your main disk from df -l output (1-based row index)
disk_index: 8

historyLength: 60  # 1 min @ 1s refresh

history: []

style: """
  // grid: col 1 · row 3 · 1×1  (see LAYOUT.md)
  top 190px
  left 10px

  color var(--text, #fff)
  text-shadow: 0 1px 1px rgba(20, 1, 1, 0.2)   // inherits to all text elements
  font-family -apple-system, BlinkMacSystemFont, system-ui, sans-serif
  display: flex
  gap: 10px

  .panel
    background var(--panel-bg, rgba(#000, .15))
    -webkit-backdrop-filter: blur(var(--panel-blur, 48px))
    backdrop-filter: blur(var(--panel-blur, 48px))
    border-radius 10px
    box-sizing: border-box
    min-height: 80px       // base minimum widget height (see LAYOUT.md)

  .panel-stats
    padding 9px 10px 12px
    display: flex          // lets stats-inner fill the 80px panel height

  .panel-graph
    padding 10px

  .stats-inner
    width: 300px
    text-align: left
    position: relative
    display: flex
    flex-direction: column   // title on top, numbers + bar pushed to the bottom

  .widget-title
    font-size 10px
    text-transform uppercase
    font-weight bold
    margin-bottom: 1px

  .disk-name
    float: right
    font-weight bold

  .widget-name
    float: left

  .stats-container
    margin-top: auto       // push the numbers + bar to the panel bottom
    margin-bottom 5px      // gap between the labels and the bar
    border-collapse collapse
    table-layout: fixed

  td
    font-size: 14px
    font-weight: 300
    text-align: left
    width: 25%

  .stat:last-child,
  .label:last-child
    text-align: right

  // Space between the numbers and their labels below them.
  .stat
    padding-bottom: 4px

  .label
    font-size 8px
    text-transform uppercase
    font-weight bold

  .bar-container
    width: 100%
    height: 6px
    border-radius: 6px
    background: var(--level-base, rgba(#fff, .2))
    position: relative
    box-shadow: 0 1px 1px rgba(20, 1, 1, 0.10)   // base bar: matches text shadow

  // Single left-anchored layer (same pattern as the multi-layer bars).
  .bar
    position: absolute
    left: 0
    top: 0
    height: 6px
    border-radius: 6px
    transition: width .2s ease-in-out
    box-shadow: 1px 0 3px rgba(0, 0, 0, 0.04)   // faint separation under the cap

  .bar-used
    background: var(--level-max, rgba(#fff, 1))

  // Fill color reflects how full the disk is — but only under a color scheme.
  // Monochrome leaves --status-* unset, so each falls through to --level-max
  // (mode-driven ink, so it flips with light/dark) rather than a static white.
  .bar-used.status-ok
    background: var(--status-ok, var(--level-max, rgba(#fff, 1)))

  .bar-used.status-warn
    background: var(--status-warn, var(--level-max, rgba(#fff, 1)))

  .bar-used.status-elevated
    background: var(--status-elevated, var(--level-max, rgba(#fff, 1)))

  .bar-used.status-critical
    background: var(--status-critical, var(--level-max, rgba(#fff, 1)))

  .graph-container
    width: 300px
    height: 53px
    position: relative
    overflow: hidden
    border: 1px solid var(--hairline, rgba(#ccc, .125))
    border-radius: 3px
    box-sizing: border-box
    padding: 1px
    background-image: radial-gradient(var(--dot-grid, rgba(#fff, .05)) 1px, transparent 1.5px)
    background-size: 10px 10px
    background-position: -4px -4px

  svg
    display: block
    width: 100%
    height: 100%

  .line-used
    fill: none
    stroke: var(--level-max, rgba(#fff, 1))
    stroke-width: 1.5
    vector-effect: non-scaling-stroke
    stroke-linejoin: round
    stroke-linecap: round

  .area-used
    fill: var(--area-fill-hi, rgba(#fff, .3))
    stroke: none

  // Graph tracks the same disk-full status as the bar. The status class is set on
  // the graph-container (a div) in update(), so the SVG line/area pick it up via
  // descendant selectors — avoids jQuery addClass quirks on SVG elements.
  .graph-container.status-ok .line-used
    stroke: var(--status-ok, rgba(#fff, 1))
  .graph-container.status-warn .line-used
    stroke: var(--status-warn, rgba(#fff, 1))
  .graph-container.status-elevated .line-used
    stroke: var(--status-elevated, rgba(#fff, 1))
  .graph-container.status-critical .line-used
    stroke: var(--status-critical, rgba(#fff, 1))

  .graph-container.status-ok .area-used
    fill: var(--status-ok-fill, rgba(#fff, .3))
  .graph-container.status-warn .area-used
    fill: var(--status-warn-fill, rgba(#fff, .3))
  .graph-container.status-elevated .area-used
    fill: var(--status-elevated-fill, rgba(#fff, .3))
  .graph-container.status-critical .area-used
    fill: var(--status-critical-fill, rgba(#fff, .3))
"""

render: -> """
  <div class="panel panel-stats">
    <div class="stats-inner">
      <div class="widget-title">
        <div class="widget-name">Storage</div>
        <div class="disk-name"></div>
      </div>
      <table class="stats-container" width="100%">
        <tr>
          <td class="stat"><span class="used"></span></td>
          <td class="stat"><span class="available"></span></td>
          <td class="stat"><span class="total"></span></td>
          <td class="stat"><span class="usage"></span></td>
        </tr>
        <tr>
          <td class="label">used</td>
          <td class="label">available</td>
          <td class="label">total</td>
          <td class="label">usage</td>
        </tr>
      </table>
      <div class="bar-container">
        <div class="bar bar-used"></div>
      </div>
    </div>
  </div>
  #{if @showGraph then """
  <div class="panel panel-graph">
    <div class="graph-container">
      <svg preserveAspectRatio="none" viewBox="0 0 59 100">
        <polygon class="area-used" points=""></polygon>
        <polyline class="line-used" points=""></polyline>
      </svg>
    </div>
  </div>
  """ else ""}
"""

update: (output, domEl) ->
  # Hide entirely when disabled.
  if not @widgetEnabled
    $(domEl).css('display', 'none')
    return
  $(domEl).css('display', '')
  usageFormat = (mb) ->
    if mb > 1000000
      tb = mb / 1000000
      "#{parseFloat(tb.toFixed(2))}TB"
    else if mb > 1000
      gb = mb / 1000
      "#{parseFloat(gb.toFixed(2))}GB"
    else
      "#{parseFloat(mb.toFixed(2))}MB"

  updateStat = (sel, usedMbs, totalMbs) ->
    percent = (usedMbs / totalMbs * 100).toFixed(1)
    $(domEl).find(".#{sel}").text usageFormat(usedMbs)
    $(domEl).find(".bar-#{sel}").css "width", percent + "%"

  lines = output.split "\n"
  return unless lines[@disk_index]
  mainDisk = lines[@disk_index].split(/\ +/)

  $(domEl).find(".disk-name").text mainDisk[8]

  totalMbs = parseFloat(mainDisk[1])
  usedMbs  = parseFloat(mainDisk[2])
  availableMbs = parseFloat(mainDisk[3])
  capacityRatio = mainDisk[4]
  return unless totalMbs > 0

  $(domEl).find(".total").text usageFormat(totalMbs)
  $(domEl).find(".usage").text capacityRatio

  updateStat 'used',      usedMbs,      totalMbs
  $(domEl).find('.available').text usageFormat(availableMbs)

  # Color the used bar by how full the disk is (only shows under a color scheme).
  # Use the displayed capacity ratio (e.g. "89%") so color tracks the shown number.
  usedPct = parseFloat(capacityRatio)
  status =
    if usedPct >= 95 then 'status-critical'
    else if usedPct >= 85 then 'status-elevated'
    else if usedPct >= 75 then 'status-warn'
    else 'status-ok'
  $(domEl).find('.bar-used, .graph-container')
    .removeClass('status-ok status-warn status-elevated status-critical')
    .addClass(status)

  return unless @showGraph

  usedPercent = usedMbs / totalMbs * 100
  @history ?= []
  @history.push usedPercent
  @history.shift() while @history.length > @historyLength

  return if @history.length < 2

  N = @historyLength
  offset = N - 1 - (@history.length - 1)
  lastX = offset + @history.length - 1
  points = @history.map((v, i) -> "#{offset + i},#{100 - v}").join(" ")
  $(domEl).find('.line-used').attr('points', points)
  $(domEl).find('.area-used').attr('points', "#{points} #{lastX},100 #{offset},100")
