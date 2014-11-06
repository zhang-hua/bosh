require 'spec_helper'
require 'bosh/dev/download_adapter'
require 'bosh/dev/local_download_adapter'
require 'bosh/dev/promoter'
require 'bosh/dev/git_tagger'
require 'bosh/dev/git_branch_merger'
require 'open3'
require 'bosh/dev/command_helper'

describe 'promotion', type: :integration do
  def exec_cmd(cmd)
    logger.info("Executing: #{cmd}")
    stdout, stderr, status = Open3.capture3(cmd)
    raise "Failed executing '#{cmd}'\nSTDOUT: '#{stdout}', \nSTDERR: '#{stderr}'" unless status.success?
    [stdout, stderr, status]
  end

  let!(:origin_repo_path) { Dir.mktmpdir(['promote_test_repo', '.git']) }
  let!(:workspace_path) { Dir.mktmpdir('promote_test_workspace') }
  before do
    Dir.chdir(origin_repo_path) do
      exec_cmd('git init --bare .')
    end
    Dir.chdir(workspace_path) do
      exec_cmd("git clone #{origin_repo_path} .")
      File.write('initial-file.go', 'initial-code')
      exec_cmd('git add -A')
      exec_cmd("git commit -m 'initial commit'")
      exec_cmd('git push origin master')
    end
    # recreate workspace dir
    FileUtils.rm_rf(workspace_path)
    Dir.mkdir(workspace_path)
  end
  after { FileUtils.rm_rf(origin_repo_path) }
  after { FileUtils.rm_rf(workspace_path) }

  before do
    allow(Bosh::Dev::DownloadAdapter).to(receive(:new).with(logger)) { Bosh::Dev::LocalDownloadAdapter.new(logger) }
    allow(build).to receive(:promoted?).and_return(false)
    #TODO: add build artifact promotion testing. for now, skip it
    allow(build).to receive(:promote)
  end

  let!(:release_patch_file) { Tempfile.new(['promote_test_release', '.patch']) }
  after { release_patch_file.delete }

  before do
    Dir.chdir(workspace_path) do
      # feature development
      exec_cmd("git clone #{origin_repo_path} .")
      exec_cmd('git checkout master')
      exec_cmd('git checkout -b feature_branch')
      File.write('feature-file.go', 'feature-code')
      exec_cmd('git add -A')
      exec_cmd("git commit -m 'added new file'")
      exec_cmd('git push origin feature_branch')

      # get candidate sha (begining of CI pipeline)
      @candidate_sha = exec_cmd('git rev-parse HEAD').first.strip

      # release creation (middle of CI pipeline)
      File.write('release-file.go', 'release-code')
      exec_cmd('git add -A')
      exec_cmd("git diff --staged > #{release_patch_file.path}")
    end

    # recreate workspace dir
    FileUtils.rm_rf(workspace_path)
    Dir.mkdir(workspace_path)

    # instead of getting the patch from S3, copy from the local patch file
    allow(Bosh::Dev::UriProvider).to receive(:release_patches_uri).with('', '0000-final-release.patch').and_return(release_patch_file.path)
  end

  # mock out the artifact builder
  let(:build) { instance_double('Bosh::Dev::Build') }
  before do
    allow(Bosh::Dev::Build).to receive(:candidate).with(logger).and_return(build)
  end

  it 'commits the release patch to a stable tag and then merges to the master and feature branches' do
    # promote (end of CI pipeline)
    Dir.chdir(workspace_path) do
      exec_cmd("git clone #{origin_repo_path} .")
      exec_cmd('git checkout feature_branch')

      rake_input_args = {
        candidate_build_number: '0000',
        candidate_sha: @candidate_sha,
        feature_branch: 'feature_branch',
        stable_branch: 'master',
      }
      promoter = Bosh::Dev::Promoter.build(rake_input_args)
      promoter.promote

      # expect new tag stable-0000 to exist
      tagger = Bosh::Dev::GitTagger.new(logger)
      tag_sha = tagger.tag_sha('stable-0000') # errors if tag does not exist
      expect(tag_sha).to_not be_empty

      # expect sha of tag to be in feature_branch and master
      merger = Bosh::Dev::GitBranchMerger.new(logger)
      expect(merger.branch_contains?('master', tag_sha)).to be(true)
      expect(merger.branch_contains?('feature_branch', tag_sha)).to be(true)
    end
  end

  it 'promotes artifacts'

  context 'when the release changes have been tagged and pushed to master' do
    before do
      # previous promote attempt
      Dir.chdir(workspace_path) do
        exec_cmd("git clone #{origin_repo_path} .")
        exec_cmd('git checkout feature_branch')

        # promotion of artifacts fails
        allow(build).to receive(:promote).and_raise('promotion-failed')

        rake_input_args = {
          candidate_build_number: '0000',
          candidate_sha: @candidate_sha,
          feature_branch: 'feature_branch',
          stable_branch: 'master',
        }
        promoter = Bosh::Dev::Promoter.build(rake_input_args)

        expect{promoter.promote}.to raise_error('promotion-failed')

        # expect new tag stable-0000 to exist
        tagger = Bosh::Dev::GitTagger.new(logger)
        @tag_sha = tagger.tag_sha('stable-0000') # errors if tag does not exist
        expect(@tag_sha).to_not be_empty

        # expect sha of tag to be in master
        merger = Bosh::Dev::GitBranchMerger.new(logger)
        expect(merger.branch_contains?('master', @tag_sha)).to be(true)
      end

      # recreate workspace dir
      FileUtils.rm_rf(workspace_path)
      Dir.mkdir(workspace_path)
    end

    it 'promotes artifacts'

    it 'merges release changes into the feature branch' do
      # promote a second time
      Dir.chdir(workspace_path) do
        exec_cmd("git clone #{origin_repo_path} .")
        exec_cmd('git checkout feature_branch')

        # promotion of artifacts suceeds
        allow(build).to receive(:promote)

        rake_input_args = {
          candidate_build_number: '0000',
          candidate_sha: @candidate_sha,
          feature_branch: 'feature_branch',
          stable_branch: 'master',
        }
        promoter = Bosh::Dev::Promoter.build(rake_input_args)
        promoter.promote

        # expect sha of tag to be in feature_branch
        merger = Bosh::Dev::GitBranchMerger.new(logger)
        expect(merger.branch_contains?('feature_branch', @tag_sha)).to be(true)
      end
    end
  end

  context 'when artifacts have been promoted' do
    before do
      allow(build).to receive(:promoted?).and_return(true)
    end

    it 'merges changes into the feature branch' do
      # promote a second time
      Dir.chdir(workspace_path) do
        exec_cmd("git clone #{origin_repo_path} .")
        exec_cmd('git checkout feature_branch')

        # instead of getting the patch from S3, copy from the local patch file
        allow(Bosh::Dev::UriProvider).to receive(:release_patches_uri).with('', '0000-final-release.patch').and_return(release_patch_file.path)

        rake_input_args = {
          candidate_build_number: '0000',
          candidate_sha: @candidate_sha,
          feature_branch: 'feature_branch',
          stable_branch: 'master',
        }
        promoter = Bosh::Dev::Promoter.build(rake_input_args)
        promoter.promote

        # expect sha of tag to be in feature_branch
        merger = Bosh::Dev::GitBranchMerger.new(logger)
        expect(merger.branch_contains?('feature_branch', @tag_sha)).to be(true)
      end
    end
  end

  context 'when release changes have been merged to the feature branch' do
    it 'does not push any more changes (tag, master or feature branch)'
  end
end
