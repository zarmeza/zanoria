# frozen_string_literal: true

require 'yaml'

# The publish path is mostly not Ruby, and the parts that are least safe to get
# wrong are the seams between the pieces: the workflow that publishes, the
# library that decides whether it may, and the rake task that starts it.
#
# The trigger is read out of the parsed YAML rather than matched as text, so
# reformatting the file does not turn the suite red. One catch: Psych reads
# the key `on:` as the boolean `true`, because YAML 1.1 counts `on` as a
# boolean and GitHub's own parser does not. The lookup below asks for both.
RSpec.describe 'the publish workflow' do
  let(:path) { File.expand_path('../.github/workflows/publish.yml', __dir__) }
  let(:yaml) { YAML.safe_load_file(path, aliases: true) }
  let(:trigger) { yaml['on'] || yaml[true] }
  let(:job) { yaml['jobs']['publish'] }
  let(:steps) { job['steps'] }
  let(:scripts) { steps.map { |step| step['run'].to_s }.join("\n") }
  let(:step_names) { steps.map { |step| step['name'].to_s } }
  let(:uses) { steps.map { |step| step['uses'].to_s }.join("\n") }

  it 'is triggered by a tag, and can be run by hand to check the path' do
    expect(trigger.keys).to eq(%w[push workflow_dispatch])
    expect(trigger['push']['tags']).to eq(['v*'])
    expect(trigger['push']).not_to have_key('branches')
  end

  it 'runs the library guard rather than a second copy of the rules' do
    expect(scripts).to include('Release.check_tag!')
  end

  # The bug this guards. `rubygems/release-gem@v1` runs
  # `bundle exec rake release` in the working directory, and in this
  # repository that is a task which guards a local release and pushes a
  # *tag* — not one that pushes a gem. The publish step failed with
  # "releases are cut from main, not HEAD", and the gem was never pushed.
  #
  # The literal string `rake release` never appears in the workflow: it is
  # inside the action. So the assertion that catches it is the action's name.
  it 'does not use the release action, which would run this repository\'s rake release task' do
    expect(uses).not_to include('rubygems/release-gem')
    expect(scripts).not_to include('rake release')
  end

  # The credentials come from the OIDC exchange, so there is no API key to
  # create, store, or rotate. A key in the repository's secrets would undo
  # the whole arrangement, and `gem push` is only safe here because of where
  # its credentials come from.
  it 'gets its credentials from the OIDC exchange rather than a stored key' do
    exchange = steps.find { |step| step['uses'].to_s.include?('configure-rubygems-credentials') }
    push = steps.find { |step| step['name'].to_s.include?('Publish') }

    expect(exchange).not_to be_nil
    expect(push).not_to be_nil
    expect(steps.index(exchange)).to be < steps.index(push)
    expect(File.read(path)).not_to include('secrets.')
  end

  # Only a tag publishes. The manual run checks the path and stops, so the
  # exchange can be exercised before the one step that cannot be undone.
  it 'publishes only on a tag' do
    publish = steps.find { |step| step['name'].to_s.include?('Publish') }

    expect(publish['if']).to eq("github.event_name == 'push'")
  end

  it 'checks before it publishes' do
    check = step_names.index { |name| name.include?('Check') }
    publish = step_names.index { |name| name.include?('Publish') }

    expect(check).not_to be_nil
    expect(publish).not_to be_nil
    expect(check).to be < publish
  end

  it 'asks for an id-token, which is what Trusted Publishing trades for push access' do
    expect(job['permissions']['id-token']).to eq('write')
  end

  it 'publishes through the release environment, which is the name the trusted publisher is registered under' do
    expect(job['environment']).to eq('release')
  end

  it 'has the whole history, because a shallow clone cannot say whether a commit is on main' do
    checkout = steps.find { |step| step['uses'].to_s.include?('actions/checkout') }

    expect(checkout['with']['fetch-depth']).to eq(0)
  end
end
