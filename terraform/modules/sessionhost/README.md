# Session Host Module

Creates the Windows Server discovery session host VM, the
`AADLoginForWindows` extension when enabled, and the AVD registration
extension.

The module accepts a separate Windows `computer_name` so the Azure VM resource
name can stay descriptive without violating the 15-character Windows hostname
limit.

This module does not install `RDPWin` or Actian. Those are lab steps after the VM is built.
