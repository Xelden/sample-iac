output "admin_ip" {
  value = azurerm_public_ip.admin_public_ip.ip_address
}

output "vpn_ip" {
  value = azurerm_public_ip.vpn_public_ip.ip_address
}

# output "dns_ip" {
#   value = azurerm_public_ip.dns_public_ip.ip_address
# }
#
# output "todo_ip" {
#   value = azurerm_public_ip.todo_public_ip.ip_address
# }
#
# output "todo2_ip" {
#   value = azurerm_public_ip.todo2_public_ip.ip_address
# }
