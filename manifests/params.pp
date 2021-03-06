
class teamcity::params {
  $username                = "teamcity"
  $server_url              = "http://builder"
  $archive_name            = "buildAgent.zip"
  $agent_dir               = "build-agent"
  $destination_dir         = "/var/tainted"
  $priority                = "20"
  $teamcity_agent_mem_opts = "-Xms128m -Xmx2048m -XX:+HeapDumpOnOutOfMemoryError"
  $work_dir                = "../work"
}
