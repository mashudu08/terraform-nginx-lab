variable "container_name" {
    description = "name of the Nginx container"
    type        = string
    default    = "terraform-nginx"
}

variable "external_port" {
    description = "external port for Nginx"
    type        = number
    default     = 8081
}
