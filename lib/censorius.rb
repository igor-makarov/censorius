# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/MethodLength

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

    def generate_paths(object, path = '')
      case object
      when Xcodeproj::Project::Object::PBXProject
        generate_paths_project(object)
      when Xcodeproj::Project::Object::AbstractTarget
        generate_paths_target(object, path)
      when Xcodeproj::Project::Object::PBXGroup
        generate_paths_group(object)
      when Xcodeproj::Project::Object::PBXFileReference
        generate_paths_file_reference(object)
      when Xcodeproj::Project::Object::XCConfigurationList
        generate_paths_configuration_list(object, path)
      when Xcodeproj::Project::Object::XCBuildConfiguration
        generate_paths_configuration(object, path)
      when Xcodeproj::Project::Object::AbstractBuildPhase
        generate_paths_phase(object, path)
      when Xcodeproj::Project::Object::PBXBuildFile
        generate_paths_build_file(object, path)
      when Xcodeproj::Project::Object::PBXContainerItemProxy
        generate_paths_container_item_proxy(object, path)
      when Xcodeproj::Project::Object::PBXTargetDependency
        generate_paths_target_dependency(object, path)
      when Xcodeproj::Project::Object::PBXReferenceProxy
        @paths_by_object[object] = "#{path}/PBXReferenceProxy(#{object.source_tree}/#{object.path})"
        generate_paths(object.remote_ref, @paths_by_object[object]) if object.remote_ref
      else
        raise "Unrecognized: #{object.class}, at: #{path}"
      end

      @paths_by_object[object]
    end

    def generate_paths_project(project)
      @paths_by_object[project] = path = "PBXProject(#{project.name})"
      generate_paths(project.main_group, path)
      generate_paths(project.build_configuration_list, path)
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
      target.build_phases.each do |phase|
        generate_paths(phase, path)
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
      file_ref_path = generate_paths(build_file.file_ref)
      @paths_by_object[build_file] = "#{parent_path}/PBXBuildFile(#{file_ref_path})"
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
      @paths_by_object[file_reference] = "#{project_path}/PBXFileReference(#{file_reference.full_path})"
    end

    def generate_paths_target_dependency(dependency, parent_path)
      raise "Unsupported: #{dependency}" unless dependency.target_proxy

      @paths_by_object[dependency] = path = "#{parent_path}/PBXTargetDependency(#{dependency.name})"
      generate_paths(dependency.target_proxy, path)
    end

    def generate_paths_container_item_proxy(proxy, parent_path)
      params = [
        "type: #{proxy.proxy_type}",
        "containerPortal: #{proxy.container_portal_annotation.strip}",
        "remoteInfo: #{proxy.remote_info}"
      ]
      @paths_by_object[proxy] = "#{parent_path}/PBXContainerItemProxy(#{params.join(', ')})"
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

# rubocop:enable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength
