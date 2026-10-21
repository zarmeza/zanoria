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

  it 'is triggered by a tag and by nothing else' do
    expect(trigger.keys).to eq(['push'])
    expect(trigger['push']['tags']).to eq(['v*'])
    expect(trigger['push']).not_to have_key('branches')
  end

  it 'runs the library guard rather than a second copy of the rules' do
    expect(scripts).to include('Release.check_tag!')
  end

  it 'does not push a gem from CI, because that would need an API key' do
    expect(scripts).not_to include('gem push')
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
