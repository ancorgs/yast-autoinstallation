#!/usr/bin/env rspec

require_relative "test_helper"

Yast.import "AutoinstFunctions"
Yast.import "Stage"
Yast.import "Mode"
Yast.import "AutoinstConfig"

describe Yast::AutoinstFunctions do

  subject { Yast::AutoinstFunctions }

  let(:stage) { "initial" }
  let(:mode) { "autoinst" }
  let(:second_stage) { true }

  before do
    Yast::Mode.SetMode(mode)
    Yast::Stage.Set(stage)
    allow(Yast::AutoinstConfig).to receive(:second_stage).and_return(second_stage)
    Yast::Profile.Import({})
  end

  describe "#second_stage_required?" do
    context "when not in initial stage" do
      let(:stage) { "continue" }

      it "returns false" do
        expect(subject.second_stage_required?).to eq(false)
      end
    end

    context "when not in autoinst or autoupgrade mode" do
      let(:mode) { "normal" }

      it "returns false" do
        expect(subject.second_stage_required?).to eq(false)
      end
    end

    context "when second stage is disabled" do
      let(:second_stage) { false }

      it "returns false" do
        expect(subject.second_stage_required?).to eq(false)
      end
    end

    context "when in autoinst mode and second stage is enabled" do
      it "relies on ProductControl.RunRequired" do
        expect(Yast::ProductControl).to receive(:RunRequired)
          .with("continue", mode).and_return(true)
        expect(subject.second_stage_required?).to eq(true)
      end
    end

    context "when in autoupgrade mode and second stage is enabled" do
      let(:mode) { "autoupgrade" }

      it "relies on ProductControl.RunRequired" do
        expect(Yast::ProductControl).to receive(:RunRequired)
          .with("continue", mode).and_return(true)
        expect(subject.second_stage_required?).to eq(true)
      end
    end
  end

  describe "#check_second_stage_environment" do
    context "second stage is not needed" do
      it "returns an empty error string" do
        allow(subject).to receive(:second_stage_required?).and_return(false)
        expect(subject.check_second_stage_environment).to be_empty
      end
    end

    context "second stage is needed" do
      before do
        allow(subject).to receive(:second_stage_required?).and_return(true)
      end

      context "required package are installed" do
        it "returns an empty error string" do
          allow(Yast::Pkg).to receive(:IsSelected).and_return(true)
          expect(subject.check_second_stage_environment).to be_empty
        end
      end

      context "required package are not installed" do
        before do
          allow(Yast::Pkg).to receive(:IsSelected).and_return(false)
        end

        context "registration has not been defined in AY configuration file" do
          it "reports error to set registration" do
            allow(Yast::Profile).to receive(:current).and_return(Yast::ProfileHash.new)
            expect(subject.check_second_stage_environment).to(
              include("configuring the registration")
            )
          end
        end

        context "registration has failed" do
          it "reports error to check registration settings" do
            allow(Yast::Profile).to receive(:current).and_return(
              "suse_register" => { "do_registration" => true }
            )
            expect(subject.check_second_stage_environment).to include("registration has failed")
          end
        end
      end
    end
  end

  describe "#selected_product" do
    def base_product(name)
      Y2Packager::Product.new(name: name)
    end

    let(:selected_name) { "SLES" }

    let(:profile) do
      { "software" => { "products" => [selected_name] } }
    end

    before(:each) do
      allow(Yast::Profile).to receive(:current).and_return(Yast::ProfileHash.new(profile))
      allow(Y2Packager::ProductReader)
        .to receive(:new)
        .and_return(double(available_base_products: [base_product("SLES"), base_product("SLED")]))

      # reset cache between tests
      subject.reset_product
    end

    context "when the base product is explicitly selected in the profile" do
      context "and the product exists on the media" do
        it "returns the corresponding base product" do
          expect(subject.selected_product.name).to eql selected_name
        end
      end

      context "and such a product does not exist on the media" do
        let(:selected_name) { "Fedora" }

        it "returns nil" do
          expect(subject.selected_product).to be nil
        end
      end
    end


    context "when the product is identified by a pattern" do
      let(:profile) do
        { "software" => { "patterns" => ["sles-base-32bit"] } }
      end

      it "returns the corresponding product" do
        expect(subject.selected_product.name).to eql selected_name
      end
    end

    context "when the product is identified by a package" do
      let(:profile) do
        { "software" => { "packages" => ["sles-release"] } }
      end

      it "returns the corresponding product" do
        expect(subject.selected_product.name).to eql selected_name
      end
    end

    context "when the product cannot be identified from the profile" do
      let(:profile) do
        { "software" => {} }
      end

      context "and only one base product exists on the media" do
        before do
          allow(Y2Packager::ProductReader)
            .to receive(:new)
            .and_return(double(available_base_products: [base_product("SLED")]))
        end

        it "returns the existing base product" do
          expect(subject.selected_product.name).to eql "SLED"
        end
      end
    end

    context "when there is not a valid software section" do
      let(:profile) { { "software" => nil } }

      it "returns nil" do
        expect(subject.selected_product).to be_nil
      end

      it "logs a message" do
        allow(subject.log).to receive(:info).and_call_original
        expect(subject.log).to receive(:info).at_least(1).with(/not a valid software section/)

        subject.selected_product
      end
    end
  end
end
