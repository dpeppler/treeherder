# Commands to run before all others in puppet.
class init {
    exec { "update_apt":
        command => "sudo apt-get update",
    }
}
