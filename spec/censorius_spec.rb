# frozen_string_literal: true

RSpec.describe Censorius::UUIDGenerator do
  before(:each) do |s|
    @spec_safe_name = s.metadata[:full_description].gsub(/[^0-9a-z]/i, '_')
    @project = Xcodeproj::Project.new("#{@spec_safe_name}.xcodeproj")
    @generator = Censorius::UUIDGenerator.new([@project])
  end

  after(:each) do
    debug_output! unless ENV['CENSORIUS_SPEC_DEBUG'].nil?
  end

  def debug_output!
    @generator.write_debug_paths
    @project.save
  end

  def recursive_add_file(path)
    group = @project.main_group
    components = path.split('/')
    components[0..-2].each do |component|
      group = group.new_group(component, component)
    end
    file = group.new_file(components.last)
    [group, file]
  end

  it 'has a version number' do
    expect(Censorius::VERSION).not_to be nil
  end

  it 'generates UUIDs for default project' do
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

  it 'generates UUIDs for file references' do
    group = @project.main_group.new_group('group', 'group')
    group.new_file('in_group.txt')
    @project.new_file('at_root.txt')
    @project.new_file('built_product.txt', :built_products)
    @generator.generate!

    expect(@project.objects_by_uuid.keys.sort).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/built_product.txt)
      PBXProject(#{@spec_safe_name})/PBXFileReference(at_root.txt)
      PBXProject(#{@spec_safe_name})/PBXFileReference(group/in_group.txt)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXGroup(/group)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].map { |k| Digest::MD5.hexdigest(k).upcase }.sort
  end

  it 'generates UUIDs for build configurations' do
    @project.add_build_configuration('OtherConfig', :debug)

    @generator.generate!

    expect(@project.objects_by_uuid.keys.sort).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(OtherConfig)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].map { |k| Digest::MD5.hexdigest(k).upcase }.sort
  end

  it 'generates UUIDs for native targets' do
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.build_phases.first.remove_from_project until target.build_phases.empty?
    @project['Frameworks/iOS'].children.first.remove_from_project
    @project['Frameworks/iOS'].remove_from_project
    @generator.generate!

    expect(@project.objects_by_uuid.keys.sort).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/AppTarget.app)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Release)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].map { |k| Digest::MD5.hexdigest(k).upcase }.sort
  end

  it 'generates UUIDs for build phases' do
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.frameworks_build_phase.files.first.remove_from_project until target.frameworks_build_phase.files.empty?
    @project['Frameworks/iOS'].children.first.remove_from_project
    @project['Frameworks/iOS'].remove_from_project

    # with dashes so that `%w[]` literals work
    target.new_copy_files_build_phase('Copy-some-files')
    target.new_copy_files_build_phase('Copy-some-more-files')
    target.new_shell_script_build_phase('Run-a-script')
    target.new_shell_script_build_phase('Run-another-script')

    @generator.generate!

    expect(@project.objects_by_uuid.keys.sort).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/AppTarget.app)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXCopyFilesBuildPhase(Copy-some-files)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXCopyFilesBuildPhase(Copy-some-more-files)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXResourcesBuildPhase(Resources)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXShellScriptBuildPhase(Run-a-script)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXShellScriptBuildPhase(Run-another-script)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXSourcesBuildPhase(Sources)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Release)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].map { |k| Digest::MD5.hexdigest(k).upcase }.sort
  end

  it 'generates UUIDs for build files' do
    _, framework = recursive_add_file('path/to/Framework.framework')
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.frameworks_build_phase.add_file_reference(framework)
    target.resources_build_phase.remove_from_project
    target.source_build_phase.remove_from_project
    @generator.generate!

    expect(@project.objects_by_uuid.keys.sort).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/AppTarget.app)
      PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework)
      PBXProject(#{@spec_safe_name})/PBXFileReference(path/to/Framework.framework)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks/iOS)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXGroup(/path)
      PBXProject(#{@spec_safe_name})/PBXGroup(/path/to)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)/PBXBuildFile(PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework))
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)/PBXBuildFile(PBXProject(#{@spec_safe_name})/PBXFileReference(path/to/Framework.framework))
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Release)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].map { |k| Digest::MD5.hexdigest(k).upcase }.sort
  end
end
