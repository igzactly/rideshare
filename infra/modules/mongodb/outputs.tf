output "cluster_name" {
  description = "Name of the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.rideshare.name
}

output "cluster_id" {
  description = "ID of the MongoDB Atlas cluster"
  value       = mongodbatlas_cluster.rideshare.id
}

output "connection_string" {
  description = "MongoDB Atlas connection string"
  value       = mongodbatlas_cluster.rideshare.connection_strings[0].standard_srv
  sensitive   = true
}

output "database_name" {
  description = "Name of the database"
  value       = mongodbatlas_database.rideshare_db.name
}

output "username" {
  description = "Database username"
  value       = mongodbatlas_database_user.rideshare_user.username
}
