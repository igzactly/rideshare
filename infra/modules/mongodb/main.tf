resource "mongodbatlas_cluster" "rideshare" {
  project_id = var.project_id
  name       = "${var.environment}-rideshare-cluster"

  provider_name               = "AWS"
  provider_region_name        = var.provider_region
  provider_instance_size_name = var.instance_size

  cluster_type = "REPLICASET"
  replication_specs {
    num_shards = 1
    regions_config {
      region_name     = var.provider_region
      electable_nodes = 3
      read_only_nodes = 0
      analytics_nodes = 0
    }
  }

  # Enable backup
  provider_backup_enabled = true
  pit_enabled            = true

  # Network access
  provider_auto_scaling_compute_enabled = false
  provider_auto_scaling_disk_gb_enabled = false

  tags = [
    {
      key   = "Environment"
      value = var.environment
    },
    {
      key   = "Project"
      value = "RideShare"
    }
  ]
}

# Database user
resource "mongodbatlas_database_user" "rideshare_user" {
  username = "${var.environment}_rideshare_user"
  password = var.database_password
  project_id = var.project_id
  auth_database_name = "admin"

  roles {
    role_name     = "readWrite"
    database_name = "rideshare"
  }

  scopes {
    name = mongodbatlas_cluster.rideshare.name
    type = "CLUSTER"
  }
}

# Network access list
resource "mongodbatlas_project_ip_access_list" "rideshare_access" {
  project_id = var.project_id
  cidr_block = var.allowed_cidr_blocks

  comment = "RideShare application access"
}

# Database
resource "mongodbatlas_database" "rideshare_db" {
  project_id = var.project_id
  name       = "rideshare"
}

# Collections (optional - can be created by the application)
resource "mongodbatlas_collection" "users" {
  project_id   = var.project_id
  cluster_name = mongodbatlas_cluster.rideshare.name
  database_name = mongodbatlas_database.rideshare_db.name
  name         = "users"
}

resource "mongodbatlas_collection" "rides" {
  project_id   = var.project_id
  cluster_name = mongodbatlas_cluster.rideshare.name
  database_name = mongodbatlas_database.rideshare_db.name
  name         = "rides"
}

resource "mongodbatlas_collection" "drivers" {
  project_id   = var.project_id
  cluster_name = mongodbatlas_cluster.rideshare.name
  database_name = mongodbatlas_database.rideshare_db.name
  name         = "drivers"
}

resource "mongodbatlas_collection" "payments" {
  project_id   = var.project_id
  cluster_name = mongodbatlas_cluster.rideshare.name
  database_name = mongodbatlas_database.rideshare_db.name
  name         = "payments"
}
