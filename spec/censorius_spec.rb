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

  def add_build_rule(target, rule_name)
    rule = @project.new(Xcodeproj::Project::Object::PBXBuildRule)
    rule.name = rule_name
    yield rule if block_given?
    target.build_rules << rule
    rule
  end

  it 'has a version number' do
    expect(Censorius::VERSION).not_to be nil
  end

  it 'generates UUIDs for default project' do
    @generator.generate!

    expect(@project.sorted_md5s).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].sorted_md5s
  end

  it 'generates UUIDs for file references' do
    @project.new_file('at_root.txt')
    recursive_add_file('group/in_group.txt')
    recursive_add_file('path/to/nested/group/nested.txt')
    @project.new_file('built_product.txt', :built_products)
    with_different_name = @project.new_file('different_file.txt')
    with_different_name.name = 'different_name'

    @generator.generate!

    expect(@project.sorted_md5s).to eq (%W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/built_product.txt)
      PBXProject(#{@spec_safe_name})/PBXFileReference(at_root.txt)
      PBXProject(#{@spec_safe_name})/PBXFileReference(group/in_group.txt)
    ] + [
      "PBXProject(#{@spec_safe_name})/PBXFileReference(name: different_name, different_file.txt)"
    ] + %W[
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXGroup(/group)
      PBXProject(#{@spec_safe_name})/PBXGroup(/path)
      PBXProject(#{@spec_safe_name})/PBXGroup(/path/to)
      PBXProject(#{@spec_safe_name})/PBXGroup(/path/to/nested)
      PBXProject(#{@spec_safe_name})/PBXGroup(/path/to/nested/group)
      PBXProject(#{@spec_safe_name})/PBXFileReference(path/to/nested/group/nested.txt)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ]).sorted_md5s
  end

  it 'generates UUIDs for build configurations' do
    @project.add_build_configuration('OtherConfig', :debug)

    @generator.generate!

    expect(@project.sorted_md5s).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(OtherConfig)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].sorted_md5s
  end

  it 'generates UUIDs for native targets' do
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.build_phases.first.remove_from_project until target.build_phases.empty?
    @project['Frameworks/iOS'].children.first.remove_from_project
    @project['Frameworks/iOS'].remove_from_project
    @generator.generate!

    expect(@project.sorted_md5s).to eq %W[
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
    ].sorted_md5s
  end

  it 'generates UUIDs for target dependencies' do
    target1 = @project.new_target(:application, 'AppTarget', :ios)
    target1.build_phases.first.remove_from_project until target1.build_phases.empty?
    target2 = @project.new_target(:framework, 'FrameworkTarget', :ios)
    target2.build_phases.first.remove_from_project until target2.build_phases.empty?
    @project['Frameworks/iOS'].children.first.remove_from_project
    @project['Frameworks/iOS'].remove_from_project
    target1.add_dependency(target2)

    other_project = Xcodeproj::Project.open('spec/fixtures/OtherProject.xcodeproj')
    Xcodeproj::Project::FileReferencesFactory.new_reference(@project.main_group, other_project.path, :group)
    target1.add_dependency(other_project.targets.first)

    @generator.generate!

    expect(@project.sorted_md5s).to eq (%W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/AppTarget.app)
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/FrameworkTarget.framework)
      PBXProject(#{@spec_safe_name})/PBXFileReference(spec/fixtures/OtherProject.xcodeproj)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)
    ] + [
      "PBXProject(#{@spec_safe_name})/PBXGroup(/Products)/PBXReferenceProxy(BUILT_PRODUCTS_DIR/FrameworkTargetInOtherProject.framework)",
      "PBXProject(#{@spec_safe_name})/PBXGroup(/Products)/PBXReferenceProxy(BUILT_PRODUCTS_DIR/FrameworkTargetInOtherProject.framework)/PBXContainerItemProxy(type: 2, containerPortal: OtherProject.xcodeproj, remoteInfo: Subproject)",

      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXTargetDependency(FrameworkTargetInOtherProject)",
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXTargetDependency(FrameworkTargetInOtherProject)/PBXContainerItemProxy(type: 1, containerPortal: OtherProject.xcodeproj, remoteInfo: FrameworkTargetInOtherProject)",
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXTargetDependency(FrameworkTarget)",
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXTargetDependency(FrameworkTarget)/PBXContainerItemProxy(type: 1, containerPortal: Project object, remoteInfo: FrameworkTarget)"
    ] + %W[
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Release)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(FrameworkTarget)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(FrameworkTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(FrameworkTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(FrameworkTarget)/XCConfigurationList/XCBuildConfiguration(Release)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ]).sorted_md5s
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

    expect(@project.sorted_md5s).to eq %W[
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
    ].sorted_md5s
  end

  it 'generates UUIDs for build files' do
    _, framework = recursive_add_file('path/to/Framework.framework')
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.frameworks_build_phase.add_file_reference(framework)
    target.resources_build_phase.remove_from_project
    target.source_build_phase.remove_from_project
    @generator.generate!

    expect(@project.sorted_md5s).to eq %W[
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
    ].sorted_md5s
  end

  it 'generates UUIDs for build rules' do
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.resources_build_phase.remove_from_project
    target.source_build_phase.remove_from_project
    add_build_rule(target, 'BuildRule1')
    @generator.generate!

    expect(@project.sorted_md5s).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/AppTarget.app)
      PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks/iOS)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXBuildRule(BuildRule1)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)/PBXBuildFile(PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework))
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Release)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].sorted_md5s
  end

  it 'generates UUIDs for aggregate targets' do
    target = @project.new_aggregate_target('AggregateTarget1')
    target.build_phases.first.remove_from_project until target.build_phases.empty?
    @generator.generate!

    expect(@project.sorted_md5s).to eq %W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXAggregateTarget(AggregateTarget1)
      PBXProject(#{@spec_safe_name})/PBXAggregateTarget(AggregateTarget1)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXAggregateTarget(AggregateTarget1)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXAggregateTarget(AggregateTarget1)/XCConfigurationList/XCBuildConfiguration(Release)
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ].sorted_md5s
  end

  it 'generates UUIDs for SwiftPM dependencies' do
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.resources_build_phase.remove_from_project
    target.source_build_phase.remove_from_project

    package_reference = @project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package_reference.repositoryURL = 'https://url.to/'
    package_reference.requirement = { kind: 'upToNextMajorVersion', minimumVersion: '5.0.0' }
    @project.root_object.package_references << package_reference
    local_package_reference = @project.new(Xcodeproj::Project::Object::XCLocalSwiftPackageReference)
    local_package_reference.relative_path = '../path/to/package'
    @project.root_object.package_references << local_package_reference

    dependency = @project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dependency.package = package_reference
    dependency.product_name = 'Product1'
    target.package_product_dependencies << dependency

    build_file = @project.new(Xcodeproj::Project::Object::PBXBuildFile)
    build_file.product_ref = dependency
    target.frameworks_build_phase.files << build_file

    target_dependency = @project.new(Xcodeproj::Project::PBXTargetDependency)
    target_dependency.product_ref = dependency
    target.dependencies << target_dependency

    @generator.generate!

    expect(@project.sorted_md5s).to eq (%W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/AppTarget.app)
      PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks/iOS)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)/PBXBuildFile(PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework))
    ] + [
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)/PBXBuildFile(PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCSwiftPackageProductDependency(PBXProject(#{@spec_safe_name})/XCRemoteSwiftPackageReference(https://url.to/, {:kind=>\"upToNextMajorVersion\", :minimumVersion=>\"5.0.0\"}), Product1))",
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXTargetDependency(PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCSwiftPackageProductDependency(PBXProject(#{@spec_safe_name})/XCRemoteSwiftPackageReference(https://url.to/, {:kind=>\"upToNextMajorVersion\", :minimumVersion=>\"5.0.0\"}), Product1))"
    ] + %W[
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Release)
    ] + [
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCSwiftPackageProductDependency(PBXProject(#{@spec_safe_name})/XCRemoteSwiftPackageReference(https://url.to/, {:kind=>\"upToNextMajorVersion\", :minimumVersion=>\"5.0.0\"}), Product1)"
    ] + %W[
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ] + [
      # declared in a weird way because of string split/escape
      "PBXProject(#{@spec_safe_name})/XCLocalSwiftPackageReference(../path/to/package)",
      "PBXProject(#{@spec_safe_name})/XCRemoteSwiftPackageReference(https://url.to/, {:kind=>\"upToNextMajorVersion\", :minimumVersion=>\"5.0.0\"})"
    ]).sorted_md5s
  end

  it 'generates UUIDs for SwiftPM dependencies when they are target-only' do
    target = @project.new_target(:application, 'AppTarget', :ios)
    target.resources_build_phase.remove_from_project
    target.source_build_phase.remove_from_project

    package_reference = @project.new(Xcodeproj::Project::Object::XCRemoteSwiftPackageReference)
    package_reference.repositoryURL = 'https://url.to/'
    package_reference.requirement = { kind: 'upToNextMajorVersion', minimumVersion: '5.0.0' }
    @project.root_object.package_references << package_reference

    dependency = @project.new(Xcodeproj::Project::Object::XCSwiftPackageProductDependency)
    dependency.package = package_reference
    dependency.product_name = 'Product1'

    target_dependency = @project.new(Xcodeproj::Project::PBXTargetDependency)
    target_dependency.product_ref = dependency
    target.dependencies << target_dependency

    @generator.generate!

    expect(@project.sorted_md5s).to eq (%W[
      PBXProject(#{@spec_safe_name})
      PBXProject(#{@spec_safe_name})/PBXFileReference(${BUILT_PRODUCTS_DIR}/AppTarget.app)
      PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework)
      PBXProject(#{@spec_safe_name})/PBXGroup(/)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Frameworks/iOS)
      PBXProject(#{@spec_safe_name})/PBXGroup(/Products)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXFrameworksBuildPhase(Frameworks)/PBXBuildFile(PBXProject(#{@spec_safe_name})/PBXFileReference(${DEVELOPER_DIR}/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS14.0.sdk/System/Library/Frameworks/Foundation.framework))
    ] + [
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/PBXTargetDependency(PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCSwiftPackageProductDependency(PBXProject(#{@spec_safe_name})/XCRemoteSwiftPackageReference(https://url.to/, {:kind=>\"upToNextMajorVersion\", :minimumVersion=>\"5.0.0\"}), Product1))"
    ] + %W[
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCConfigurationList/XCBuildConfiguration(Release)
    ] + [
      "PBXProject(#{@spec_safe_name})/PBXNativeTarget(AppTarget)/XCSwiftPackageProductDependency(PBXProject(#{@spec_safe_name})/XCRemoteSwiftPackageReference(https://url.to/, {:kind=>\"upToNextMajorVersion\", :minimumVersion=>\"5.0.0\"}), Product1)"
    ] + %W[
      PBXProject(#{@spec_safe_name})/XCConfigurationList
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Debug)
      PBXProject(#{@spec_safe_name})/XCConfigurationList/XCBuildConfiguration(Release)
    ] + [
      # declared in a weird way because of string split/escape
      "PBXProject(#{@spec_safe_name})/XCRemoteSwiftPackageReference(https://url.to/, {:kind=>\"upToNextMajorVersion\", :minimumVersion=>\"5.0.0\"})"
    ]).sorted_md5s
  end
end
