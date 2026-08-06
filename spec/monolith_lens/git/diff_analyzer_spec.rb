# frozen_string_literal: true

require "tmpdir"

RSpec.describe MonolithLens::Git::DiffAnalyzer do
  def git(dir, *args)
    system("git", "-C", dir, *args, out: File::NULL, err: File::NULL)
  end

  it "lists only the ruby files changed between two refs" do
    Dir.mktmpdir do |dir|
      git(dir, "init", "-q")
      git(dir, "config", "user.email", "t@example.com")
      git(dir, "config", "user.name", "Test")
      File.write(File.join(dir, "a.rb"), "class A; end\n")
      File.write(File.join(dir, "readme.md"), "hi\n")
      git(dir, "add", "-A")
      git(dir, "commit", "-q", "-m", "init")

      File.write(File.join(dir, "a.rb"), "class A; def x; end; end\n")
      File.write(File.join(dir, "b.rb"), "class B; end\n")
      git(dir, "add", "-A")
      git(dir, "commit", "-q", "-m", "change")

      changed = described_class.changed_ruby_files(repo: dir, base: "HEAD~1", head: "HEAD")

      expect(changed).to contain_exactly("a.rb", "b.rb")
    end
  end
end
