require 'json'

def check(value, message)
  raise message unless value
end

histories = Dir.glob(File.join(ARGV.fetch(0), 'histories', '*'))
check(histories.length == 6, 'Expected exactly six newly executed scenario histories')
scenarios = []
histories.each do |directory|
  seed = JSON.parse(File.read(File.join(directory, 'seed.json')))
  mode = seed.fetch('mode')
  snapshots = Dir.glob(File.join(directory, 'Evidence', '*.json')).sort.map { |p| JSON.parse(File.read(p)) }
  states = snapshots.map { |s| s.fetch('films').first }
  # Swift Set encoding has no array-order contract across processes.
  states.compact.each { |s| s['development']['completedSequences'].sort! if s['development'] }
  check(snapshots.first.fetch('reason') == 'seeded', "#{mode}: initial state missing")
  reasons = snapshots.map { |s| s.fetch('reason') }
  scenario = mode
  states.compact.each do |s|
    check(s.fetch('film').fetch('id') == seed.fetch('filmID'), "#{mode}: Film identity changed")
  end
  case mode
  when 'empty'
    check(snapshots.length == 3, 'Empty scenario inspections incomplete')
    check(states[0] == states[1], 'Delete cancellation changed empty Film')
    check(states[0].fetch('film').fetch('captures').empty?, 'Empty Film captured')
    check(snapshots[2].fetch('films').empty?, 'Confirmed delete retained Film')
    check(snapshots[2].fetch('privateFiles').none? { |p| p.start_with?('Media/', 'Staging/', 'Work/') }, 'Private assets remain after deletion')
  when 'early-photo'
    check(snapshots.length == 5, 'Early/originals scenario inspections incomplete')
    check(states[0] == states[1], 'Early cancellation changed saved state')
    check(states[2].fetch('film').fetch('developmentState') == 'notStarted', 'Development occurred without second confirmation')
    check(states[2].fetch('film').fetch('completionState').dig('completedEarly', 'wasted', 'exposures', '_0') == 25, 'Wrong irrevocable early waste')
    check(states[2].fetch('film').fetch('captures').all? { |c| c.fetch('revealState') == 'sealed' }, 'Early completion exposed a photo')
    check(states[3] == states[4], 'Reopen changed revealed Film, recipes, media or choices')
    states[3].fetch('captures').each do |c|
      check(c.fetch('originalDisposition') == {'exportRequested'=>{}}, 'Original choice not retained as pending export')
      check(c['sourceSHA256'] && c['masterSHA256'] && c['printSHA256'], 'Sources or verified outputs lost before original export')
    end
    check(snapshots[4].fetch('reason') == 'reopen', 'No ordinary process reopen evidence')
  when 'instant-mixed'
    check(snapshots.length == 3, 'Instant inspections incomplete')
    check(states[0].fetch('film').fetch('captures').map { |c| c.fetch('revealState') } == %w[revealed sealed], 'Initial Instant reveal is not individual')
    check(states[0].fetch('captures')[1]['masterSHA256'].nil?, 'Second sealed print already has developed master')
    check(states[1].fetch('film').fetch('captures').map { |c| c.fetch('revealState') } == %w[revealed revealed], 'Resume did not reveal remaining Instant print')
    check(states[0].fetch('captures')[0] == states[1].fetch('captures')[0], 'First revealed print changed on second reveal')
    check(states[0].fetch('development').fetch('assignments').fetch('1') == states[1].fetch('development').fetch('assignments').fetch('1'), 'First assignment changed')
    check(states[1].fetch('film').fetch('completionState') == {'open'=>{}}, 'Instant pack completed early')
    # DEV-12 asks once only after the Instant pack is full, so neither revealed print has an Originals choice here.
    check(states[1].fetch('captures')[1]['originalDisposition'].nil?, 'An unfinished pack recorded an Originals choice')
    check(states[1].fetch('captures')[1]['sourceSHA256'], 'Original of the newly revealed print was removed before the pack was full')
    check(states[1].fetch('captures')[1]['masterSHA256'], 'Revealed print lost its developed master')
    check(states[1].fetch('captures')[0]['originalDisposition'].nil?, 'Answer reached a print that was not asked about')
    check(states[1].fetch('captures')[0]['sourceSHA256'], 'Original of a print that was not asked about was removed')
    check(states[1] == states[2], 'Instant reopen changed durable state')
  when 'developed-photo'
    original = states[0].fetch('captures')[0]
    # The harness records every requested inspection as 'explicit'; each test's sequence differs.
    if reasons == %w[seeded explicit reopen explicit reopen]
      scenario = 'developed-photo-reset'
      check(snapshots.length == 5, 'Darkroom inspections incomplete')
      edited = states[1].fetch('captures')[0]
      reset = states[3].fetch('captures')[0]
      check(edited.fetch('recipe').fetch('printExposureStops') != 0, 'Edit was not saved')
      check(original.fetch('printSHA256') != edited.fetch('printSHA256'), 'Edit did not affect actual print bytes')
      check(states[1] == states[2], 'Saved edit changed on reopen')
      check(reset == original, 'Reset did not restore exact original print/recipe/source/master state')
      check(states[3] == states[4], 'Reset changed on reopen')
    elsif reasons == %w[seeded explicit]
      scenario = 'developed-photo-controls'
      check(snapshots.length == 2, 'Darkroom control inspections incomplete')
      saved = states[1].fetch('captures')[0]
      check(saved.fetch('recipe').key?('colorFiltration'), 'Filtration edit was not saved')
      check(!saved.fetch('recipe').key?('crop'), 'Crop that was switched off was saved')
      check(saved.fetch('recipe').fetch('dodgeBurnMasks').empty?, 'The recipe without legacy strokes changed unexpectedly')
      check(original.fetch('printSHA256') != saved.fetch('printSHA256'), 'Saved control edits did not change the print')
    elsif reasons == %w[seeded explicit explicit reopen explicit]
      scenario = 'developed-photo-legacy-stroke-reset'
      check(snapshots.length == 5, 'Legacy stroke and Reset inspections incomplete')
      loaded = states[1].fetch('captures')[0]
      masks = loaded.fetch('recipe').fetch('dodgeBurnMasks')
      check(masks.length == 1 && masks[0].fetch('kind') == 'burn', 'Stored legacy stroke was not loaded')
      check(original.fetch('printSHA256') != loaded.fetch('printSHA256'), 'Stored legacy stroke did not change the printed bytes')
      reset = states[2].fetch('captures')[0]
      check(reset.fetch('recipe').fetch('dodgeBurnMasks').empty?, 'Reset retained a legacy stroke')
      check(reset.fetch('recipe') == original.fetch('recipe'), 'Reset did not restore the original recipe')
      check(reset.fetch('printSHA256') == original.fetch('printSHA256'), 'Reset did not restore the exact original print bytes')
      check(states[2] == states[3] && states[3] == states[4], 'Reset result changed on reopen or inspection')
    else
      raise "Unexpected developed-photo history #{reasons.inspect}"
    end
    states.each do |s|
      check(s.fetch('captures')[1] == states[0].fetch('captures')[1], 'Editing photo 1 changed photo 2')
      check(s.fetch('development') == states[0].fetch('development'), 'Darkroom rerolled Development')
    end
  else
    raise "Unexpected scenario #{mode}"
  end
  scenarios << scenario
  puts "PASS #{scenario}: #{snapshots.length} native inspections, #{File.basename(directory)}"
end
check(scenarios.sort == %w[developed-photo-controls developed-photo-legacy-stroke-reset developed-photo-reset early-photo empty instant-mixed], 'Missing or duplicated scenario')
puts 'Bounded UI/state evidence only; no Camera, Photos, Security, StoreKit or hardware acceptance.'
