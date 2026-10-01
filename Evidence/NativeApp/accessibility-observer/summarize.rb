require 'json'

folder = File.join(__dir__, 'stage-1')
geometry = File.readlines(File.join(folder, 'geometry.log')).map do |line|
  JSON.parse(line.partition(' ')[2])
end
activity = File.readlines(File.join(folder, 'test-activity.txt')).map do |line|
  match = line.match(/^AUDIT_PROBE time=([0-9.]+) uptime=[0-9.]+ event=(\S+)(.*)$/)
  match && { 'time' => match[1].to_f, 'event' => match[2], 'detail' => match[3].strip }
end.compact
launches = activity.select { |event| event['event'] == 'launch' }

result = launches.each_with_index.map do |launch, index|
  finish = launches[index + 1]&.fetch('time') || Float::INFINITY
  records = geometry.select { |record| record['time'] >= launch['time'] && record['time'] < finish }
  main_scrolls = records.select { |record| record['event'] == 'native-scroll' && record['windowFrame'][2] == 402 }
  bars = records.select { |record| record['event'] == 'native-navigation' && record['title'] == '16mm' }
  gaps = main_scrolls.map do |scroll|
    bar = bars.reverse.find { |record| record['time'] <= scroll['time'] }
    bar && scroll['windowFrame'][1] - bar['windowFrame'][1] - bar['windowFrame'][3]
  end.compact
  captures = records.select { |record| record['event'] == 'size-screen' }
  spans = captures.map { |record| record['time'] - record['captureStart'] }.sort
  observations = activity.select do |event|
    event['time'] >= launch['time'] && event['time'] < finish &&
      event['event'].match?(/audit-call|callback-1.enter|audit-returned/)
  end.map do |event|
    scroll = main_scrolls.reverse.find { |record| record['time'] <= event['time'] }
    bar = bars.reverse.find { |record| record['time'] <= event['time'] }
    labels = %w[camera-description film-title trial-label].map do |id|
      records.reverse.find { |record| record['id'] == id && record['time'] <= event['time'] }
    end.compact
    event.merge('lastScroll' => scroll, 'lastNavigation' => bar, 'lastLabels' => labels)
  end
  {
    'launch' => launch, 'mainScrollObservations' => main_scrolls.length,
    'adjustedInsets' => main_scrolls.map { |record| record['adjustedInset'] }.uniq,
    'sequentialNavigationGapRange' => [gaps.min, gaps.max],
    'windowCaptures' => captures.length,
    'captureSeconds' => spans.empty? ? nil : { 'min' => spans.first, 'median' => spans[spans.length / 2], 'max' => spans.last },
    'disabledCaptureCallbacks' => records.count { |record| record['event'] == 'size-screen-disabled' },
    'auditObservations' => observations
  }
end

# These are latest preceding observations, not simultaneous analyzer samples.
puts JSON.pretty_generate(result)
