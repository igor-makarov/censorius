# frozen_string_literal: true

require 'json'
require 'xcodeproj'

require_relative 'censorius/version'

module Censorius
  # The main generator class
  class UUIDGenerator < Xcodeproj::Project::UUIDGenerator
    def generate_all_paths_by_objects(projects)
      projects.each do |project|
        generate_paths(project.root_object, project.path.basename.to_s)
        without_path = project.objects.select { |o| @paths_by_object[o].nil? }
        raise "Without paths: #{without_path}" unless without_path.empty?
      end
    end

    def generate_paths(object, parent_path = '') # rubocop:disable Metrics/CyclomaticComplexity
      case object
      when Xcodeproj::Project::Object::PBXProject
        generate_paths_project(object)
      when Xcodeproj::Project::Object::AbstractTarget
        generate_paths_target(object, parent_path)
      when Xcodeproj::Project::Object::PBXGroup
        generate_paths_group(object)
      when Xcodeproj::Project::Object::PBXFileReference
        generate_paths_file_reference(object)
      when Xcodeproj::Project::Object::XCConfigurationList
        generate_paths_configuration_list(object, parent_path)
      when Xcodeproj::Project::Object::XCBuildConfiguration
        generate_paths_configuration(object, parent_path)
      when Xcodeproj::Project::Object::AbstractBuildPhase
        generate_paths_phase(object, parent_path)
      when Xcodeproj::Project::Object::PBXBuildFile
        generate_paths_build_file(object, parent_path)
      when Xcodeproj::Project::Object::PBXBuildRule
        generate_paths_build_rule(object, parent_path)
      when Xcodeproj::Project::Object::PBXContainerItemProxy
        generate_paths_container_item_proxy(object, parent_path)
      when Xcodeproj::Project::Object::PBXTargetDependency
        generate_paths_target_dependency(object, parent_path)
      when Xcodeproj::Project::Object::PBXReferenceProxy
        generate_paths_reference_proxy(object, parent_path)
      when Xcodeproj::Project::Object::XCRemoteSwiftPackageReference
        generate_paths_remote_swift_package_reference(object, parent_path)
      when Xcodeproj::Project::Object::XCLocalSwiftPackageReference
        generate_paths_local_swift_package_reference(object, parent_path)
      when Xcodeproj::Project::Object::XCSwiftPackageProductDependency
        generate_paths_swift_package_product_dependency(object, parent_path)
      else
        raise "Unrecognized: #{object.class}, at: #{parent_path}"
      end

      @paths_by_object[object]
    end

    def generate_paths_project(project)
      @paths_by_object[project] = path = "PBXProject(#{project.name})"
      generate_paths(project.main_group, path)
      generate_paths(project.build_configuration_list, path)
      project.package_references.each do |package_reference|
        generate_paths(package_reference, path)
      end
      project.project_references.each do |ref|
        product_group = ref[:product_group]
        generate_paths(product_group, path) if product_group
      end
      project.targets.each do |target|
        generate_paths(target, path)
      end
    end

    def generate_paths_configuration_list(configuration_list, parent_path)
      @paths_by_object[configuration_list] = path = "#{parent_path}/XCConfigurationList"
      configuration_list.build_configurations.each do |config|
        generate_paths(config, path)
      end
    end

    def generate_paths_configuration(configuration, parent_path)
      @paths_by_object[configuration] = "#{parent_path}/XCBuildConfiguration(#{configuration.name})"
    end

    def generate_paths_target(target, parent_path)
      @paths_by_object[target] = path = "#{parent_path}/#{target.class.name.split('::').last}(#{target.name})"
      if target.respond_to?(:package_product_dependencies)
        target.package_product_dependencies.each do |dependency|
          generate_paths(dependency, path)
        end
      end
      target.build_phases.each do |phase|
        generate_paths(phase, path)
      end
      if target.respond_to?(:build_rules)
        target.build_rules.each do |rule|
          generate_paths(rule, path)
        end
      end
      generate_paths(target.build_configuration_list, path)
      target.dependencies.each do |dependency|
        generate_paths(dependency, path)
      end
    end

    def generate_paths_phase(phase, parent_path)
      @paths_by_object[phase] = path = "#{parent_path}/#{phase.class.name.split('::').last}(#{phase.display_name})"
      phase.files.each do |file|
        generate_paths(file, path)
      end
    end

    def generate_paths_build_file(build_file, parent_path)
      if build_file.file_ref
        file_ref_path = generate_paths(build_file.file_ref)
        @paths_by_object[build_file] = "#{parent_path}/PBXBuildFile(#{file_ref_path})"
      elsif build_file.product_ref
        @paths_by_object[build_file.product_ref] ||= generate_paths(dependency.product_ref, parent_path)
        product_ref_path = @paths_by_object[build_file.product_ref]
        @paths_by_object[build_file] = "#{parent_path}/PBXBuildFile(#{product_ref_path})"
      else
        raise "Unsupported: #{build_file}"
      end
    end

    def generate_paths_build_rule(build_rule, parent_path)
      @paths_by_object[build_rule] = "#{parent_path}/PBXBuildRule(#{build_rule.name})"
    end

    def generate_paths_group(group)
      project_path = @paths_by_object[group.project.root_object]
      @paths_by_object[group] = path = "#{project_path}/PBXGroup(#{group.hierarchy_path || '/'})"
      group.children.each do |child|
        generate_paths(child, path)
      end
    end

    def generate_paths_file_reference(file_reference)
      project_path = @paths_by_object[file_reference.project.root_object]
      params = []
      if !file_reference.name.nil? &&
         !file_reference.name.empty? &&
         file_reference.name != File.basename(file_reference.full_path, '.*') &&
         file_reference.name != File.basename(file_reference.full_path)
        params << "name: #{file_reference.name}"
      end
      params << file_reference.full_path.to_s

      @paths_by_object[file_reference] = "#{project_path}/PBXFileReference(#{params.join(', ')})"
    end

    def generate_paths_target_dependency(dependency, parent_path)
      if dependency.target_proxy
        @paths_by_object[dependency] = path = "#{parent_path}/PBXTargetDependency(#{dependency.name})"
        generate_paths(dependency.target_proxy, path)
      elsif dependency.product_ref
        @paths_by_object[dependency.product_ref] ||= generate_paths(dependency.product_ref, parent_path)
        product_ref_path = @paths_by_object[dependency.product_ref]
        @paths_by_object[dependency] = "#{parent_path}/PBXTargetDependency(#{product_ref_path})"
      else
        raise "Unsupported: #{dependency}"
      end
    end

    def generate_paths_container_item_proxy(proxy, parent_path)
      params = [
        "type: #{proxy.proxy_type}",
        "containerPortal: #{proxy.container_portal_annotation.strip}",
        "remoteInfo: #{proxy.remote_info}"
      ]
      @paths_by_object[proxy] = "#{parent_path}/PBXContainerItemProxy(#{params.join(', ')})"
    end

    def generate_paths_reference_proxy(proxy, parent_path)
      @paths_by_object[proxy] = path = "#{parent_path}/PBXReferenceProxy(#{proxy.source_tree}/#{proxy.path})"
      generate_paths(proxy.remote_ref, path) if proxy.remote_ref
    end

    def generate_paths_remote_swift_package_reference(reference, parent_path)
      params = [
        reference.repositoryURL,
        reference.requirement
      ]
      @paths_by_object[reference] = "#{parent_path}/XCRemoteSwiftPackageReference(#{params.join(', ')})"
    end

    def generate_paths_local_swift_package_reference(reference, parent_path)
      params = [
        reference.relative_path
      ]
      @paths_by_object[reference] = "#{parent_path}/XCLocalSwiftPackageReference(#{params.join(', ')})"
    end

    def generate_paths_swift_package_product_dependency(dependency, parent_path)
      params = [
        @paths_by_object[dependency.package],
        dependency.product_name
      ]
      @paths_by_object[dependency] = "#{parent_path}/XCSwiftPackageProductDependency(#{params.join(', ')})"
    end

    def write_debug_paths
      return if @projects.empty?

      debug_info = @paths_by_object
                   .to_a
                   .map(&:last)
                   .sort
      file_name = @projects.count == 1 ? File.basename(@projects.first.path, '.*') : 'multi'
      File.write("#{file_name}.txt", debug_info.join("\n"))
    end
  end
end
