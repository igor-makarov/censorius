# frozen_string_literal: true

RSpec.describe Censorius::UUIDGenerator do
  before(:each) do |s|
    @spec_safe_name = s.metadata[:full_description].gsub(/[^0-9a-z]/i, '_')
    @project = Xcodeproj::Project.new("#{@spec_safe_name}.xcodeproj")
    @generator = Censorius::UUIDGenerator.new([@project])
  end

  def debug_output!
    @generator.write_debug_paths
    @project.save
  end

  it 'has a version number' do
    expect(Censorius::VERSION).not_to be nil
  end

  it 'generates deterministic UUIDs' do
    @generator.generate!

    expect(@project.objects_by_uuid.keys.sort).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].map { |k| Digest::MD5.hexdigest(k).upcase }.sort
  end
end
