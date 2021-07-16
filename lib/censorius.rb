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
        @paths_by_object[object] = "PBXProject(#{object.name})"
        generate_paths(object.main_group, @paths_by_object[object])
        generate_paths(object.build_configuration_list, @paths_by_object[object])
        object.targets.each do |target|
          generate_paths(target, @paths_by_object[object])
        end
      when Xcodeproj::Project::Object::AbstractTarget
        @paths_by_object[object] = "#{path}/#{object.class.name.split('::').last}(#{object.name})"
        object.build_phases.each do |phase|
          generate_paths(phase, @paths_by_object[object])
        end
        generate_paths(object.build_configuration_list, @paths_by_object[object])
        object.dependencies.each do |dependency|
          generate_paths(dependency, @paths_by_object[object])
        end
      when Xcodeproj::Workspace::FileReference
        @paths_by_object[object] = "FileReference(#{object.path})"
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
        @paths_by_object[object] = "#{object.target.class.name.split('::').last}(#{object.target})/XCConfigurationList"
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
        params = [object.proxy_type, object.container_portal_annotation, object.remote_info]
        @paths_by_object[object] = "#{path}/PBXContainerItemProxy(type:#{params.join(',')})"
      when Xcodeproj::Project::Object::PBXTargetDependency
        raise "Unsupported: #{object}" unless object.target_proxy

        prefix = "#{path}/PBXTargetDependency(#{object.name})"
        proxy_name = generate_paths(object.target_proxy, prefix)
        @paths_by_object[object] = "#{path}/PBXTargetDependency(#{object.name}, #{proxy_name})"
      when Xcodeproj::Project::Object::PBXReferenceProxy
        @paths_by_object[object] = "#{path}/PBXReferenceProxy(#{object.source_tree}/#{object.path})"
        generate_paths(object.remote_ref, @paths_by_object[object]) if object.remote_ref
      else
        raise "Unrecognized: #{object.class}"
      end

      @paths_by_object[object]
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
