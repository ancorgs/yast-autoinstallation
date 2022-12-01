#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "Profile"
Yast.import "AutoinstClone"

describe Yast::Profile do

  CUSTOM_MODULE = {
    "Name"                       => "Custom module",
    "X-SuSE-YaST-AutoInst"       => "configure",
    "X-SuSE-YaST-Group"          => "System",
    "X-SuSE-YaST-AutoInstClient" => "custom_auto"
  }.freeze

  subject { Yast::Profile }

  def items_list(items)
    Yast::Profile.current["software"][items] || []
  end

  def packages_list
    items_list("packages")
  end

  def patterns_list
    items_list("patterns")
  end

  def reboot_scripts
    Yast::Profile.current["scripts"]["init-scripts"].select do |s|
      s["filename"] == "zzz_reboot"
    end
  end

  describe "#softwareCompat" do
    before do
      Yast::Profile.current = profile
      allow(Yast::AutoinstFunctions).to receive(:second_stage_required?)
        .and_return(second_stage_required)
    end

    let(:second_stage_required) { true }

    context "when autoyast2-installation is not selected to be installed" do
      let(:profile) { Yast::ProfileHash.new("software" => { "packages" => [] }) }

      context "and second stage is required" do
        it "adds 'autoyast2-installation' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to include("autoyast2-installation")
        end
      end

      context "and second stage is not required" do
        let(:second_stage_required) { false }

        it "does not add 'autoyast2-installation' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not eq(["autoyast2-installation"])
        end
      end

      context "and second stage is disabled on the profile itself" do
        let(:profile) do
          Yast::ProfileHash.new(
            "general"  => { "mode" => { "second_stage" => false } },
            "software" => { "packages" => [] }
          )
        end

        it "does not add 'autoyast2-installation' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not include(["autoyast2-installation"])
        end
      end
    end

    context "when some section handled by a client included in autoyast2 package is present" do
      let(:profile) { Yast::ProfileHash.new("scripts" => []) }

      context "and second stage is required" do
        it "adds 'autoyast2' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to include("autoyast2")
        end
      end

      context "and second stage is not required" do
        let(:second_stage_required) { false }

        it "does not add 'autoyast2' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not include("autoyast2")
        end
      end

      context "and second stage is disabled on the profile itself" do
        let(:profile) do
          Yast::ProfileHash.new(
            "general" => { "mode" => { "second_stage" => false } },
            "files"   => []
          )
        end

        it "does not add 'autoyast2' to packages list" do
          Yast::Profile.softwareCompat
          expect(packages_list).to_not include(["autoyast2-installation"])
        end
      end
    end

    context "when the software patterns section is empty" do
      let(:profile) { Yast::ProfileHash.new("software" => { "patterns" => [] }) }

      it "adds 'base' pattern" do
        Yast::Profile.softwareCompat
        expect(patterns_list).to include("base")
      end
    end

    context "when the software patterns section is missing" do
      let(:profile) { Yast::ProfileHash.new }

      it "adds 'base' pattern" do
        Yast::Profile.softwareCompat
        expect(patterns_list).to include("base")
      end
    end
  end

  describe "#generalCompat" do
    before do
      Yast::Profile.current = profile
    end

    context "when a custom reboot script is not present" do
      let(:profile) { { "general" => { "mode" => { "final_reboot" => true } } } }

      it "adds a reboot script for the 'final_reboot' flag" do
        Yast::Profile.generalCompat
        expect(reboot_scripts).to_not be_empty
      end
    end

    # the first stage adds a custom script for the "final_reboot" flag,
    # ensure the second stage does not add it again (bsc#1188356)
    context "when a custom reboot script is present" do
      let(:profile) do
        { "general" => { "mode" => { "final_reboot" => true } },
          "scripts" => { "init-scripts" => [
            { "filename" => "zzz_reboot", "source" => "shutdown -r now" }
          ] } }
      end

      it "does not duplicate the reboot script" do
        Yast::Profile.generalCompat
        expect(reboot_scripts.size).to eq(1)
      end
    end
  end

  describe "#Import" do
    let(:profile) { Yast::ProfileHash.new }

    context "when profile is given in the old format" do
      context "and 'install' key is present" do
        let(:profile) { Yast::ProfileHash.new("install" => { "section1" => ["val1"] }) }

        it "move 'install' items to the root of the profile" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section1"]).to eq(["val1"])
          expect(Yast::Profile.current["install"]).to be_nil
        end
      end

      context "and 'configure' key is present" do
        let(:profile) { Yast::ProfileHash.new("configure" => { "section2" => ["val2"] }) }

        it "move 'configure' items to the root of the profile" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section2"]).to eq(["val2"])
          expect(Yast::Profile.current["configure"]).to be_nil
        end
      end

      context "when both keys are present" do
        let(:profile) do
          Yast::ProfileHash.new(
            "configure" => { "section2" => ["val2"] },
            "install"   => { "section1" => ["val1"] }
          )
        end

        it "merge them into the root of the profile" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section1"]).to eq(["val1"])
          expect(Yast::Profile.current["section2"]).to eq(["val2"])
          expect(Yast::Profile.current["install"]).to be_nil
          expect(Yast::Profile.current["configure"]).to be_nil
        end
      end

      context "when both keys are present and some section is duplicated" do
        let(:profile) do
          Yast::ProfileHash.new(
            "configure" => { "section1" => "val3", "section2" => ["val2"] },
            "install"   => { "section1" => ["val1"] }
          )
        end

        it "merges them into the root of the profile giving precedence to 'installation' section" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["section1"]).to eq(["val1"])
          expect(Yast::Profile.current["section2"]).to eq(["val2"])
          expect(Yast::Profile.current["install"]).to be_nil
          expect(Yast::Profile.current["configure"]).to be_nil
        end
      end
    end

    it "sets general compatibility options" do
      expect(Yast::Profile).to receive(:generalCompat)
      Yast::Profile.Import(profile)
    end

    it "sets software compatibility options" do
      expect(Yast::Profile).to receive(:softwareCompat)
      Yast::Profile.Import(profile)
    end

    context "when the profile contains an aliased resource" do
      let(:custom_module) do
        CUSTOM_MODULE.merge(
          "X-SuSE-YaST-AutoInstResourceAliases" => "old_custom"
        )
      end

      before do
        # reset singleton
        allow(Yast::Desktop).to receive(:Modules)
          .and_return("custom" => custom_module)
        reset_singleton(Y2Autoinstallation::Entries::Registry)
      end

      context "and configuration for the resource is missing" do
        let(:profile) { { "old_custom" => { "dummy" => true } } }

        it "reuses the aliased configuration" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current.keys).to_not include("old_custom")
          expect(Yast::Profile.current["custom"]).to eq("dummy" => true)
        end
      end

      context "and configuration for the resource is present" do
        let(:profile) { { "old_custom" => { "dummy" => true }, "custom" => { "dummy" => false } } }

        it "removes the aliased configuration" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current.keys).to_not include("old_custom")
          expect(Yast::Profile.current["custom"]).to eq("dummy" => false)
        end
      end

      context "and no configuration is present" do
        let(:profile) { {} }

        it "does not set any configuration for the resource" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current.keys).to_not include("old_custom")
          expect(Yast::Profile.current.keys).to_not include("custom")
        end
      end

      context "and resource has also an alternate name" do
        let(:profile) { { "old_custom" => { "dummy" => true } } }
        let(:custom_module) do
          CUSTOM_MODULE.merge(
            "X-SuSE-YaST-AutoInstResource"        => "new_custom",
            "X-SuSE-YaST-AutoInstResourceAliases" => "old_custom"
          )
        end

        it "uses the alternate name" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["new_custom"]).to eq("dummy" => true)
        end
      end

      context "and more than one aliased name is used" do
        let(:profile) { { "other_alias" => { "dummy" => true } } }
        let(:custom_module) do
          CUSTOM_MODULE.merge(
            "X-SuSE-YaST-AutoInstResourceAliases" => "other_alias,old_custom"
          )
        end

        it "takes into account all aliases" do
          Yast::Profile.Import(profile)
          expect(Yast::Profile.current["custom"]).to eq("dummy" => true)
        end
      end
    end
  end

  describe "#remove_sections" do
    before do
      Yast::Profile.Import("section1" => "val1", "section2" => "val2")
    end

    context "when a single section is given" do
      it "removes that section" do
        Yast::Profile.remove_sections("section1")
        expect(Yast::Profile.current.keys).to_not include("section1")
        expect(Yast::Profile.current.keys).to include("section2")
      end
    end

    context "when multiple sections are given" do
      it "removes every given section" do
        Yast::Profile.remove_sections(%w[section1 section2])
        expect(Yast::Profile.current.keys).to_not include("section1")
        expect(Yast::Profile.current.keys).to_not include("section2")
      end
    end
  end

  describe "#Prepare" do
    let(:prepare) { true }
    let(:custom_module) { CUSTOM_MODULE }
    let(:custom_export) { { "key1" => "val1" } }
    let(:module_map) { { "custom" => custom_module } }

    before do
      # reset singleton
      allow(Yast::Desktop).to receive(:Modules)
        .and_return(module_map)
      reset_singleton(Y2Autoinstallation::Entries::Registry)
      allow(Yast::WFM).to receive(:CallFunction).and_call_original
      allow(Yast::WFM).to receive(:CallFunction)
        .with("custom_auto", ["GetModified"]).and_return(true)
      allow(Yast::WFM).to receive(:CallFunction)
        .with("custom_auto", ["Export", "target" => "default"]).and_return(custom_export)
      allow(Yast::AutoinstClone).to receive(:General)
        .and_return("mode" => { "confirm" => false })

      subject.Reset
      subject.prepare = prepare
    end

    it "exports modules data into the current profile" do
      subject.Prepare
      expect(subject.current["custom"]).to be_kind_of(Hash)
    end

    context "when a 'target' is given" do
      it "exports the module data using the given 'target'" do
        expect(Yast::WFM).to receive(:CallFunction)
          .with("custom_auto", ["Export", "target" => "compact"])
        subject.Prepare(target: :compact)
      end
    end

    context "when preparation is not needed" do
      let(:prepare) { false }

      it "does not set the current profile" do
        subject.Prepare
        expect(subject.current).to be_empty
      end
    end

    context "when a module is 'hidden'" do
      let(:custom_module) { CUSTOM_MODULE.merge("Hidden" => "true") }

      it "includes that module" do
        subject.Prepare
        expect(subject.current.keys).to include("custom")
      end
    end

    context "when a module exports empty data" do
      let(:custom_export) { {} }

      it "removes section from Profile" do
        subject.current["custom"] = { "bla" => "bla" }
        subject.Prepare
        expect(subject.current.keys).to_not include("custom")
      end
    end

    context "when a module has not changed" do
      before do
        allow(Yast::WFM).to receive(:CallFunction)
          .with("custom_auto", ["GetModified"]).and_return(false)
      end

      it "does not include that module" do
        subject.Prepare
        expect(subject.current).to_not have_key("custom")
      end
    end

    context "when a module has elements to merge" do
      let(:custom_export) do
        {
          "users"    => [{ "username" => "root" }],
          "defaults" => { "key1" => "val1" }
        }
      end
      let(:custom_module) do
        CUSTOM_MODULE.merge(
          "X-SuSE-YaST-AutoInstClient"     => "custom_auto",
          "X-SuSE-YaST-AutoInstMerge"      => "users,defaults",
          "X-SuSE-YaST-AutoInstMergeTypes" => "list,map"
        )
      end

      it "adds each element into the current profile" do
        subject.Prepare
        expect(subject.current["users"]).to eq(custom_export["users"])
        expect(subject.current["defaults"]).to eq(custom_export["defaults"])
      end

      context "but there is no content for some of the elements" do
        let(:custom_export) do
          { "defaults" => { "key1" => "val1" } }
        end

        it "does not include the element with no content" do
          subject.Prepare
          expect(subject.current).to_not have_key("users")
        end
      end
    end

    context "when a module uses an alternative resource name" do
      let(:custom_module) do
        CUSTOM_MODULE.merge("X-SuSE-YaST-AutoInstResource" => "alternative")
      end

      it "uses the alternative name" do
        subject.Prepare
        expect(subject.current).to include("alternative")
        expect(subject.current).to_not include("custom")
      end
    end
  end

  describe "#create" do
    let(:custom_module) { CUSTOM_MODULE }
    let(:custom_export) { { "key1" => "val1" } }
    let(:module_map) { { "custom" => custom_module } }

    before do
      # reset singleton
      allow(Yast::Desktop).to receive(:Modules)
        .and_return(module_map)
      reset_singleton(Y2Autoinstallation::Entries::Registry)
      allow(Yast::WFM).to receive(:CallFunction).and_call_original
      allow(Yast::WFM).to receive(:CallFunction)
        .with("custom_auto", ["Export", "target" => "default"]).and_return(custom_export)
    end

    it "exports modules data into the current profile" do
      subject.create(["custom"])
      expect(subject.current["custom"]).to be_kind_of(Hash)
    end

    context "when a module is 'hidden'" do
      let(:custom_module) { CUSTOM_MODULE.merge("Hidden" => "true") }

      it "includes that module" do
        subject.create(["custom"])
        expect(subject.current.keys).to include("custom")
      end
    end

    context "when a module exports empty data" do
      let(:custom_export) { {} }

      it "does not include it" do
        subject.create(["custom"])
        expect(subject.current).to eq({})
      end
    end

    context "when a module has elements to merge" do
      let(:custom_export) do
        {
          "users"    => [{ "username" => "root" }],
          "defaults" => { "key1" => "val1" }
        }
      end
      let(:custom_module) do
        CUSTOM_MODULE.merge(
          "X-SuSE-YaST-AutoInstClient"     => "custom_auto",
          "X-SuSE-YaST-AutoInstMerge"      => "users,defaults",
          "X-SuSE-YaST-AutoInstMergeTypes" => "list,map"
        )
      end

      it "creates each element in the current profile" do
        subject.create(["custom"])
        expect(subject.current["users"]).to eq(custom_export["users"])
        expect(subject.current["defaults"]).to eq(custom_export["defaults"])
      end

      context "but there is no content for some of the elements" do
        let(:custom_export) do
          { "defaults" => { "key1" => "val1" } }
        end

        it "does not include the element with no content" do
          subject.create(["custom"])
          expect(subject.current).to_not have_key("users")
        end
      end
    end

    context "when a module uses an alternative resource name" do
      let(:custom_module) do
        CUSTOM_MODULE.merge("X-SuSE-YaST-AutoInstResource" => "alternative")
      end

      it "uses the alternative name" do
        subject.create("alternative")
        expect(subject.current).to include("alternative")
        expect(subject.current).to_not include("custom")
      end
    end
  end

  describe "#ReadXML" do
    let(:path) { File.join(FIXTURES_PATH, "profiles", xml_file) }

    before do
      subject.main
    end

    context "when the file is valid" do
      let(:xml_file) { "partitions.xml" }

      it "returns true" do
        expect(subject.ReadXML(path)).to eq(true)
      end

      it "imports the file content" do
        expect(subject).to receive(:Import).with(Hash)
        subject.ReadXML(path)
      end
    end

    context "when the file content is invalid" do
      let(:xml_file) { "invalid.xml" }

      before do
        allow(Yast2::Popup).to receive(:show)
      end

      it "returns false" do
        expect(subject.ReadXML(path)).to eq(false)
      end

      it "displays an error message" do
        expect(Yast2::Popup).to receive(:show)
        subject.ReadXML(path)
      end

      it "does not import the file content" do
        expect(subject).to_not receive(:Import)
        subject.ReadXML(path)
      end
    end

    context "when the content is encrypted" do
      let(:xml_file) { "profile.xml.asc" }

      before do
        allow(Yast::UI).to receive(:UserInput).and_return(:ok)
        allow(Yast::UI).to receive(:QueryWidget).with(:password, :Value)
          .and_return("nots3cr3t")
        allow(Yast::UI).to receive(:OpenDialog).and_return(true)
      end

      around do |example|
        FileUtils.cp(File.join(FIXTURES_PATH, "profiles", "minimal.xml.asc"), path)
        example.run
        FileUtils.rm(path)
      end

      it "decrypts and imports the file content" do
        expect(subject).to receive(:Import).with(Hash)
        subject.ReadXML(path)
      end

      context "during the first stage" do
        before do
          allow(Yast::Stage).to receive(:initial).and_return(true)
        end

        it "saves the unencrypted content" do
          subject.ReadXML(path)
          expect(File.read(path)).to_not include("BEGIN PGP MESSAGE")
        end
      end
    end
  end

  describe "#Save" do
    before do
      # TODO: test also encrypted autoyast
      allow(Yast::AutoinstConfig).to receive(:ProfileEncrypted).and_return(false)
    end

    it "returns true if saved profile to file" do
      expect(Yast::XML).to receive(:YCPToXMLFile).and_return(true)

      expect(subject.Save("test")).to eq true
    end

    it "returns false when failed" do
      allow(subject).to receive(:Prepare)
      subject.current = { "test" => nil }

      expect(subject.Save("Test")).to eq false
    end
  end

  describe "#SaveSingleSections" do
    before do
      allow(subject).to receive(:Prepare)
    end

    it "returns list of saved sections" do
      subject.current = { "test" => {} }
      expect(Yast::XML).to receive(:YCPToXMLFile).and_return(true)

      expect(subject.SaveSingleSections("/tmp")).to eq("test" => "/tmp/test.xml")
    end

    it "it does not return sections that failed to save" do
      allow(subject).to receive(:Prepare)
      subject.current = { "test" => nil }

      expect(subject.SaveSingleSections("/tmp")).to eq({})
    end
  end

  describe "#set_element_by_path" do
    let(:profile) { double("profile") }
    let(:value) { double("value") }
    let(:new_profile) { double("new_profile") }

    context "when a string is given as path" do
      it "sets the element by using the path's parts" do
        expect(subject).to receive(:setElementByList).with(
          ["users", 0, "username"], value, profile
        ).and_return(new_profile)
        result = subject.set_element_by_path("users,0,username", value, profile)
        expect(result).to eq(new_profile)
      end
    end

    context "when a profile path object is given as path" do
      let(:path) { Installation::AutoinstProfile::ElementPath.from_string("groups,0,name") }
      it "sets the element by using the path's parts" do
        expect(subject).to receive(:setElementByList).with(
          ["groups", 0, "name"], value, profile
        ).and_return(new_profile)
        result = subject.set_element_by_path(path, value, profile)
        expect(result).to eq(new_profile)
      end
    end
  end

  describe "#setElementByList" do
    let(:profile) do
      {
        "users" => [
          { "username" => "root" },
          { "username" => "guest" }
        ]
      }
    end
    let(:path) { ["users", 1, "username"] }

    context "when the element exists" do
      it "replaces its value" do
        new_profile = subject.setElementByList(path, "admin", profile)
        expect(new_profile["users"][1]).to eq(
          "username" => "admin"
        )
      end
    end

    context "when the element does not exist" do
      let(:path) { ["users", 1, "realname"] }

      it "adds the element in the given path" do
        new_profile = subject.setElementByList(path, "Guest User", profile)
        expect(new_profile["users"][1]).to eq(
          "username" => "guest", "realname" => "Guest User"
        )
      end
    end

    context "when the element is supposed to be an array member but it does not exist" do
      let(:path) { ["users", 3, "username"] }

      it "adds an element to the array" do
        new_profile = subject.setElementByList(path, "admin", profile)
        expect(new_profile["users"][3]).to eq(
          "username" => "admin"
        )
      end

      it "fills any gap with nil" do
        new_profile = subject.setElementByList(path, "admin", profile)
        expect(new_profile["users"][2]).to be_nil
      end
    end

    context "when parent elements are missing" do
      let(:path) { ["groups", 0, "name"] }

      it "adds all the full hierarchy up to the given path" do
        new_profile = subject.setElementByList(path, "root", profile)
        expect(new_profile["groups"]).to eq(
          [{ "name" => "root" }]
        )
      end
    end
  end

  describe "#ReadProfileStructure" do
    context "when the file does not exist" do
      let(:file_path) { FIXTURES_PATH.join("missing.ycp").to_s }

      it "returns false" do
        expect(subject.ReadProfileStructure(file_path)).to eq(false)
      end

      it "resets Profile.current" do
        subject.Import("general" => { "self_update" => false })
        subject.ReadProfileStructure(file_path)
        expect(subject.current).to eq(Yast::ProfileHash.new)
      end
    end

    context "when the structure is empty" do
      let(:file_path) { FIXTURES_PATH.join("empty-autoconf.ycp").to_s }

      it "returns false" do
        expect(subject.ReadProfileStructure(file_path)).to eq(false)
      end

      it "resets Profile.current" do
        subject.Import("general" => { "self_update" => false })
        subject.ReadProfileStructure(file_path)
        expect(subject.current).to eq(Yast::ProfileHash.new)
      end
    end

    context "when there is some valid YCP content" do
      let(:file_path) { FIXTURES_PATH.join("autoconf.ycp").to_s }

      it "returns true" do
        expect(subject.ReadProfileStructure(file_path)).to eq(true)
      end

      it "imports the file contents" do
        subject.Import("general" => { "self_update" => false })
        expect(subject).to receive(:Import).with(
          Yast::ProfileHash.new("general" => { "mode" => { "confirm" => false } })
        )
        subject.ReadProfileStructure(file_path)
      end
    end
  end
end
