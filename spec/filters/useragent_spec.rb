# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/useragent"

describe LogStash::Filters::UserAgent do

  describe "defaults" do
    config <<-CONFIG
      filter {
        useragent {
          source => "message"
          target => "ua"
        }
      }
    CONFIG

    sample "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.63 Safari/537.31" do
      insist { subject }.include?("ua")
      insist { subject.get("[ua][name]") } == "Chrome"
      insist { subject.get("[ua][os]") } == "Linux"
      insist { subject.get("[ua][major]") } == "26"
      insist { subject.get("[ua][minor]") } == "0"
    end
  end

  describe "Without target field" do
    config <<-CONFIG
      filter {
        useragent {
          source => "message"
        }
      }
    CONFIG

    sample "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.63 Safari/537.31" do
      insist { subject.get("name") } == "Chrome"
      insist { subject.get("os") } == "Linux"
      insist { subject.get("major") } == "26"
      insist { subject.get("minor") } == "0"
    end
  end

  describe "Without user agent" do
    config <<-CONFIG
      filter {
        useragent {
          source => "message"
          target => "ua"
        }
      }
    CONFIG

    sample "foo" => "bar" do
      reject { subject }.include?("ua")
    end

    sample "" do
      reject { subject }.include?("ua")
    end
  end

  describe "Specifying fields" do
    config <<-CONFIG
      filter {
        useragent {
          source => "message"
          fields => ["name", "version", "os", "os_version", "device"]
        }
      }
    CONFIG

    sample "Mozilla/5.0 (Windows NT 6.1; WOW64; rv:31.0) Gecko/20130401 Firefox/31.0" do
      expect(subject).not_to include("os_major")
      expect(subject).not_to include("major")
      insist { subject.get("os") } == "Windows 7"
      insist { subject.get("name") } == "Firefox"
      insist { subject.get("version") } == "31.0"
    end
  end

  describe "LRU object identity" do
    let(:ua_string) { "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_10_5) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/45.0.2454.85 Safari/537.36" }
    let(:uafilter) { LogStash::Filters::UserAgent.new("source" => "foo") }
    let(:ua_data) { uafilter.lookup_useragent(ua_string) }

    subject(:target) { LogStash::Event.new("foo" => ua_string) }

    before do
      uafilter.register

      # Stub this out because this UA doesn't have this field
      allow(ua_data.version).to receive(:patch_minor).and_return("foo")

      # expect(event).receive(:lookup_useragent)
      uafilter.filter(target)
    end

    {
      "name" => lambda {|uad| uad.name},
      "os" => lambda {|uad| uad.os.to_s},
      "os_name" => lambda {|uad| uad.os.name},
      "os_version" => lambda {|uad| uad.os.version.to_s},
      "os_major" => lambda {|uad| uad.os.version.major},
      "os_minor" => lambda {|uad| uad.os.version.minor},
      "device" => lambda {|uad| uad.device.to_s},
      "version" => lambda {|uad| uad.version.to_s},
      "major" => lambda {|uad| uad.version.major},
      "minor" => lambda {|uad| uad.version.minor},
      "patch" => lambda {|uad| uad.version.patch},
      "build" => lambda {|uad| uad.version.patch_minor}
    }.each do |field, uad_getter|
      context "for the #{field} field" do
        let(:value) {uad_getter.call(ua_data)}
        let(:target_field) { target.get(field)}

        it "should not have a nil value" do
          expect(target_field).to be_truthy
        end

        it "should have equivalent values" do
          expect(target_field).to eql(value)
        end

        it "should dup/clone the field to prevent cache corruption" do
          expect(target_field.object_id).not_to eql(value.object_id)
        end
      end
    end
  end

  describe "Replace source with target" do
    config <<-CONFIG
      filter {
        useragent {
          source => "message"
          target => "message"
        }
      }
    CONFIG

    sample "Mozilla/5.0 (X11; Linux i686) AppleWebKit/537.31 (KHTML, like Gecko) Chrome/26.0.1410.63 Safari/537.31" do
      insist { subject.to_hash }.include?("message")
      insist { subject.get("[message][name]") } == "Chrome"
      insist { subject.get("[message][os]") } == "Linux"
      insist { subject.get("[message][major]") } == "26"
      insist { subject.get("[message][minor]") } == "0"
    end
  end
end
