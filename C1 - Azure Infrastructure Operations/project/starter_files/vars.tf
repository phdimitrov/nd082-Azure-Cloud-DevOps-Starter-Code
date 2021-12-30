variable "prefix" {
  description = "The prefix which should be used for all resources in this example."
  default = "udacity-pr1"
}

variable "location"{
  description = "The Azure Region in which all resources in this example should be created."
  default = "West Europe"
}

variable "vm_count" {
  description = "Count of virtual machines to create"
  default = 2
}

variable "image_name" {
  description = "Image name created by packer"
  default = "UdacityProject1Image"
  sensitive = true
}

variable "username" {
  description = "Default VM username"
  default = "AzureUser"
}

variable "password" {
  description = "Default VM user's password"
  default = "P@ssw0rd1234!"
  sensitive = true
}