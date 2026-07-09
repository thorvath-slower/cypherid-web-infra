# CZID-219: restore the czid_org_zone_id output that prod/web's
# data.terraform_remote_state.idseq-prod read depends on (surfaced by CZID-218).
# The czid.org zone is not managed in this account -- its aws_route53_zone
# resources in route53.tf are commented out -- so source the id via a data
# lookup of the existing zone, matching the pattern CZID-92 established for the
# prod maintenance/email/zendesk stacks. Switch this back to the managed
# resource only if/when the czid.org resources here are re-adopted.
data "aws_route53_zone" "czid-org" {
  name         = "czid.org"
  private_zone = false
}

output "czid_org_zone_id" {
  value = data.aws_route53_zone.czid-org.zone_id
}
#
# output "czid_org_name_servers" {
#   value = aws_route53_zone.czid-org.name_servers
# }
#
# output "idseq_net_zone_id" {
#   value = aws_route53_zone.idseq-net.zone_id
# }
#
# output "idseq_net_name_servers" {
#   value = aws_route53_zone.idseq-net.name_servers
# }
#
# output "prod_happy_czid_org_zone_id" {
#   value = aws_route53_zone.prod-happy-czid-org.zone_id
# }
#
# output "prod_happy_czid_org_name_servers" {
#   value = aws_route53_zone.prod-happy-czid-org.name_servers
# }
