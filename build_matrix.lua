local t = ...

-- The artifact configuration and the finalizer are in the project root folder.
t:setVar(nil, 'jonchki_artifact_configuration', '${prj_root}/muhkuh_webui.xml')
t:setVar(nil, 'define_finalizer', '${prj_root}/finalizer.lua')

-- Create a release list for each build.
t:setVar(nil, 'define_release_list_path', table.concat({
  '${prj_root}',
  'targets',
  '${artifact_id}',
  '${platform_distribution_id}_${platform_distribution_version}_${platform_cpu_architecture}',
  'release_list.json'
}, '/'))

-- Set the repository for all NUP files.
t:setVar(nil, 'define_nup_repository', 'jonchki')

t:registerAction(
  'generate_nup_files',
  t.actionGenerateNupFiles,
  nil,
  nil,
  90
)

t:createArtifacts{
  'webui'
}

-- Build for ARM64, RISCV64 and x86_64 on Ubuntu 22.04 .
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '22.04',
  platform_cpu_architecture = 'arm64'
}, true)
--[[
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '22.04',
  platform_cpu_architecture = 'riscv64'
}, true)
t:addBuildToAllArtifacts({
  platform_distribution_id = 'ubuntu',
  platform_distribution_version = '22.04',
  platform_cpu_architecture = 'x86_64'
}, true)
--]]
t:build()

return true
