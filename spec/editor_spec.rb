# encoding: utf-8

require 'helper'

describe T::Editor do
  context 'when editing a file' do
    before do
      allow(T::Editor).to receive(:edit) do |path|
        File.open(path, 'wb') do |f|
          f.write('A tweet!!!!')
        end
      end
    end

    it 'fetches your tweet content without comments' do
      expect(T::Editor.gets).to eq('A tweet!!!!')
    end
  end

  context 'when fetching the editor to write in' do
    context 'no $VISUAL or $EDITOR set' do
      before do
        ENV['EDITOR'] = ENV['VISUAL'] = nil
      end

      context 'host_os is Mac OSX' do
        it 'returns the system editor' do
          RbConfig::CONFIG['host_os'] = 'darwin12.2.0'
          expect(T::Editor.editor).to eq('vi')
        end
      end

      context 'host_os is Linux' do
        it 'returns the system editor' do
          RbConfig::CONFIG['host_os'] = '3.2.0-4-amd64'
          expect(T::Editor.editor).to eq('vi')
        end
      end

      context 'host_os is Windows' do
        it 'returns the system editor' do
          RbConfig::CONFIG['host_os'] = 'mswin'
          expect(T::Editor.editor).to eq('notepad')
        end
      end
    end

    context '$VISUAL is set' do
      before do
        ENV['EDITOR'] = nil
        ENV['VISUAL'] = '/my/vim/install'
      end

      it 'returns the system editor' do
        expect(T::Editor.editor).to eq('/my/vim/install')
      end
    end

    context '$EDITOR is set' do
      before do
        ENV['EDITOR'] = '/usr/bin/subl'
        ENV['VISUAL'] = nil
      end

      it 'returns the system editor' do
        expect(T::Editor.editor).to eq('/usr/bin/subl')
      end
    end

    context '$VISUAL and $EDITOR are set' do
      before do
        ENV['EDITOR'] = '/my/vastly/superior/editor'
        ENV['VISUAL'] = '/usr/bin/emacs'
      end

      it 'returns the system editor' do
        expect(T::Editor.editor).to eq('/usr/bin/emacs')
      end
    end
  end

  context 'when fetching system editor' do
    context 'on a mac' do
      before do
        RbConfig::CONFIG['host_os'] = 'darwin12.2.0'
      end
      it "returns 'vi' on a unix machine" do
        expect(T::Editor.system_editor).to eq('vi')
      end
    end

    context 'on a Windows POC' do
      before do
        RbConfig::CONFIG['host_os'] = 'mswin'
      end
      it "returns 'notepad' on a windows box" do
        expect(T::Editor.system_editor).to eq('notepad')
      end
    end
  end
end
