require 'json'

def check(value, message)
  raise message unless value
end

histories = Dir.glob(File.join(ARGV.fetch(0), 'histories', '*'))
check(histories.length == 4, 'Expected exactly four newly executed scenario histories')
modes = []
histories.each do |directory|
  seed = JSON.parse(File.read(File.join(directory, 'seed.json')))
  mode = seed.fetch('mode')
  modes << mode
  snapshots = Dir.glob(File.join(directory, 'Evidence', '*.json')).sort.map { |p| JSON.parse(File.read(p)) }
  states = snapshots.map { |s| s.fetch('films').first }
  # Swift Set encoding has no array-order contract across processes.
  states.compact.each { |s| s['development']['completedSequences'].sort! if s['development'] }
  check(snapshots.first.fetch('reason') == 'seeded', "#{mode}: initial state missing")
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
    check(states[1] == states[2], 'Instant reopen changed durable state')
  when 'developed-photo'
    check(snapshots.length == 5, 'Darkroom inspections incomplete')
    original = states[0].fetch('captures')[0]
    edited = states[1].fetch('captures')[0]
    reset = states[3].fetch('captures')[0]
    check(edited.fetch('recipe').fetch('printExposureStops') != 0, 'Edit was not saved')
    check(original.fetch('printSHA256') != edited.fetch('printSHA256'), 'Edit did not affect actual print bytes')
    check(states[1] == states[2], 'Saved edit changed on reopen')
    check(reset == original, 'Reset did not restore exact original print/recipe/source/master state')
    check(states[3] == states[4], 'Reset changed on reopen')
    states.each do |s|
      check(s.fetch('captures')[1] == states[0].fetch('captures')[1], 'Editing photo 1 changed photo 2')
      check(s.fetch('development') == states[0].fetch('development'), 'Darkroom rerolled Development')
    end
  else
    raise "Unexpected scenario #{mode}"
  end
  puts "PASS #{mode}: #{snapshots.length} native inspections, #{File.basename(directory)}"
end
check(modes.sort == %w[developed-photo early-photo empty instant-mixed], 'Missing or duplicated scenario')
puts 'Bounded UI/state evidence only; no Camera, Photos, Security, StoreKit or hardware acceptance.'
