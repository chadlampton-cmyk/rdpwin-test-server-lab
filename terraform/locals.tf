locals {
  tags = merge(
    {
      Project     = var.project_name
      Environment = var.environment_name
      Group       = var.group
      ManagedBy   = "OpenTofu"
      Repository  = "rdpwin-test-server-lab"
      Workstream  = "RDPWin Azure Lab"
    },
    var.additional_tags
  )

  vm_login_scopes = {
    sessionhost = module.sessionhost.vm_resource_id
    dbserver    = module.dbserver.vm_resource_id
  }

  vm_user_login_assignments = {
    for pair in setproduct(keys(local.vm_login_scopes), toset(var.vm_user_login_principal_ids)) :
    "${pair[0]}::${pair[1]}::user" => {
      scope        = local.vm_login_scopes[pair[0]]
      principal_id = pair[1]
      role_name    = "Virtual Machine User Login"
    }
  }

  vm_admin_login_assignments = {
    for pair in setproduct(keys(local.vm_login_scopes), toset(var.vm_admin_login_principal_ids)) :
    "${pair[0]}::${pair[1]}::admin" => {
      scope        = local.vm_login_scopes[pair[0]]
      principal_id = pair[1]
      role_name    = "Virtual Machine Administrator Login"
    }
  }

  vm_login_assignments = merge(
    local.vm_user_login_assignments,
    local.vm_admin_login_assignments
  )

  avd_app_group_scopes = merge(
    {
      remoteapp = module.appgroup.remoteapp_group_id
    },
    var.enable_desktop_app_group ? {
      desktop = module.appgroup.desktop_group_id
    } : {}
  )

  legacy_avd_user_assignments = {
    for pair in setproduct(keys(local.avd_app_group_scopes), toset(var.avd_user_principal_ids)) :
    "${pair[0]}::${pair[1]}::avd-user" => {
      scope        = local.avd_app_group_scopes[pair[0]]
      principal_id = pair[1]
      role_name    = "Desktop Virtualization User"
    }
  }

  avd_desktop_user_assignments = var.enable_desktop_app_group ? {
    for principal_id in toset(var.avd_desktop_user_principal_ids) :
    "desktop::${principal_id}::avd-user" => {
      scope        = module.appgroup.desktop_group_id
      principal_id = principal_id
      role_name    = "Desktop Virtualization User"
    }
  } : {}

  avd_remoteapp_user_assignments = {
    for principal_id in toset(var.avd_remoteapp_user_principal_ids) :
    "remoteapp::${principal_id}::avd-user" => {
      scope        = module.appgroup.remoteapp_group_id
      principal_id = principal_id
      role_name    = "Desktop Virtualization User"
    }
  }

  avd_user_assignments = (
    length(var.avd_desktop_user_principal_ids) == 0 &&
    length(var.avd_remoteapp_user_principal_ids) == 0
  ) ? local.legacy_avd_user_assignments : merge(
    local.avd_desktop_user_assignments,
    local.avd_remoteapp_user_assignments
  )
}
