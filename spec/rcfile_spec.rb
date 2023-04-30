# encoding: utf-8

require 'helper'

describe T::RCFile do
  after do
    described_class.instance.reset
    FileUtils.rm_f("#{project_path}/tmp/trc")
  end

  it 'is a singleton' do
    expect(described_class).to be_a Class
    expect do
      described_class.new
    end.to raise_error(NoMethodError, /private method `new' called/)
  end

  describe '#[]' do
    it 'returns the profiles for a user' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile['testcli'].keys).to eq %w[abc123]
    end
  end

  describe '#[]=' do
    it 'adds a profile for a user' do
      rcfile = described_class.instance
      rcfile.path = "#{project_path}/tmp/trc"
      rcfile['testcli'] = {
        'abc123' => {
          username: 'testcli',
          consumer_key: 'abc123',
          consumer_secret: 'def456',
          token: 'ghi789',
          secret: 'jkl012',
        },
      }
      expect(rcfile['testcli'].keys).to eq %w[abc123]
    end

    it 'is not be world writable' do
      rcfile = described_class.instance
      rcfile.path = "#{project_path}/tmp/trc"
      rcfile['testcli'] = {
        'abc123' => {
          username: 'testcli',
          consumer_key: 'abc123',
          consumer_secret: 'def456',
          token: 'ghi789',
          secret: 'jkl012',
        },
      }
      expect(File.world_writable?(rcfile.path)).to be_nil
    end

    it 'is not be world readable' do
      rcfile = described_class.instance
      rcfile.path = "#{project_path}/tmp/trc"
      rcfile['testcli'] = {
        'abc123' => {
          username: 'testcli',
          consumer_key: 'abc123',
          consumer_secret: 'def456',
          token: 'ghi789',
          secret: 'jkl012',
        },
      }
      expect(File.world_readable?(rcfile.path)).to be_nil
    end
  end

  describe '#configuration' do
    it 'returns configuration' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile.configuration.keys).to eq %w[default_profile]
    end
  end

  describe '#active_consumer_key' do
    it 'returns default consumer key' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile.active_consumer_key).to eq 'abc123'
    end
  end

  describe '#active_consumer_secret' do
    it 'returns default consumer secret' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile.active_consumer_secret).to eq 'asdfasd223sd2'
    end
  end

  describe '#active_profile' do
    it 'returns default profile' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile.active_profile).to eq %w[testcli abc123]
    end
  end

  describe '#active_profile=' do
    it 'sets default profile' do
      rcfile = described_class.instance
      rcfile.path = "#{project_path}/tmp/trc"
      rcfile.active_profile = {'username' => 'testcli', 'consumer_key' => 'abc123'}
      expect(rcfile.active_profile).to eq %w[testcli abc123]
    end
  end

  describe '#active_token' do
    it 'returns default token' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile.active_token).to eq '428004849-cebdct6bwobn'
    end
  end

  describe '#active_secret' do
    it 'returns default secret' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile.active_secret).to eq 'epzrjvxtumoc'
    end
  end

  describe '#delete' do
    it 'deletes the rcfile' do
      path = "#{project_path}/tmp/trc"
      File.write(path, YAML.dump({}))
      expect(File.exist?(path)).to be true
      rcfile = described_class.instance
      rcfile.path = path
      rcfile.delete
      expect(File.exist?(path)).to be false
    end
  end

  describe '#empty?' do
    context 'when a non-empty file exists' do
      it 'returns false' do
        rcfile = described_class.instance
        rcfile.path = "#{fixture_path}/.trc"
        expect(rcfile.empty?).to be false
      end
    end

    context 'when file does not exist at path' do
      it 'returns true' do
        rcfile = described_class.instance
        rcfile.path = File.expand_path('fixtures/foo', __dir__)
        expect(rcfile.empty?).to be true
      end
    end
  end

  describe '#load_file' do
    context 'when file exists at path' do
      it 'loads data from file' do
        rcfile = described_class.instance
        rcfile.path = "#{fixture_path}/.trc"
        expect(rcfile.load_file['profiles']['testcli']['abc123']['username']).to eq 'testcli'
      end
    end

    context 'when file does not exist at path' do
      it 'loads default structure' do
        rcfile = described_class.instance
        rcfile.path = File.expand_path('fixtures/foo', __dir__)
        expect(rcfile.load_file.keys.sort).to eq %w[configuration profiles]
      end
    end
  end

  describe '#path' do
    it 'defaults to ~/.trc' do
      expect(described_class.instance.path).to eq File.join(File.expand_path('~'), '.trc')
    end
  end

  describe '#path=' do
    it 'overrides path' do
      rcfile = described_class.instance
      rcfile.path = "#{project_path}/tmp/trc"
      expect(rcfile.path).to eq "#{project_path}/tmp/trc"
    end

    it 'reloads data' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile['testcli']['abc123']['username']).to eq 'testcli'
    end
  end

  describe '#profiles' do
    it 'returns profiles' do
      rcfile = described_class.instance
      rcfile.path = "#{fixture_path}/.trc"
      expect(rcfile.profiles.keys).to eq %w[testcli]
    end
  end
end
