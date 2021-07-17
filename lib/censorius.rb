# frozen_string_literal: true

# rubocop:disable Metrics/AbcSize, Metrics/CyclomaticComplexity, Metrics/PerceivedComplexity, Metrics/MethodLength

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
        project_path = @paths_by_object[object.project.root_object]
        @paths_by_object[object] = "#{project_path}/PBXGroup(#{object.hierarchy_path || '/'})"
        object.children.each do |child|
          generate_paths(child, @paths_by_object[object])
        end
      when Xcodeproj::Project::Object::PBXFileReference
        project_path = @paths_by_object[object.project.root_object]
        @paths_by_object[object] = "#{project_path}/PBXFileReference(#{object.full_path})"
      when Xcodeproj::Project::Object::XCConfigurationList
        @paths_by_object[object] = "#{path}/XCConfigurationList"
        object.build_configurations.each do |config|
          generate_paths(config, @paths_by_object[object])
        end
      when Xcodeproj::Project::Object::XCBuildConfiguration
        @paths_by_object[object] = "#{path}/XCBuildConfiguration(#{object.name})"
      when Xcodeproj::Project::Object::AbstractBuildPhase
        @paths_by_object[object] = "#{path}/#{object.class.name.split('::').last}(#{object.display_name})"
        object.files.each do |file|
          generate_paths(file, @paths_by_object[object])
        end
      when Xcodeproj::Project::Object::PBXBuildFile
        file_ref_path = generate_paths(object.file_ref)
        @paths_by_object[object] = "#{path}/PBXBuildFile(#{file_ref_path})"
      when Xcodeproj::Project::Object::PBXContainerItemProxy
        params = [
          "type: #{object.proxy_type}",
          "containerPortal: #{object.container_portal_annotation.strip}",
          "remoteInfo: #{object.remote_info}"
        ]
        @paths_by_object[object] = "#{path}/PBXContainerItemProxy(#{params.join(', ')})"
      when Xcodeproj::Project::Object::PBXTargetDependency
        raise "Unsupported: #{object}" unless object.target_proxy

        @paths_by_object[object] = "#{path}/PBXTargetDependency(#{object.name})"
        generate_paths(object.target_proxy, @paths_by_object[object])
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
