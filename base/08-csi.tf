locals {
  aws-ebs-csi-driver-url = "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/v${var.helm_release["aws-ebs-csi-driver"]}/helm-chart.tgz"
}

# resource "helm_release" "aws-ebs-csi" {
#   name = "aws-ebs-csi-driver"
#   namespace = "kube-system"
#   chart = local.aws-ebs-csi-driver-url
#   version = var.helm_release["aws-ebs-csi-driver"]
# }

data "template_file" "aws-ebs-storage-class" {
  template = <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ebs
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
EOF
}

# resource "null_resource" "aws-ebs-storage-class" {
#   provisioner "local-exec" {
#     command = <<EOF
# cat <<EOL | kubectl -n kube-system apply -f -
# ${data.template_file.aws-ebs-storage-class.rendered}
# EOL
# EOF
#     environment = {
#       KUBECONFIG = var.kubeconfig_filename
#     }
#   }
#   triggers = {
#     build_number = sha1(data.template_file.aws-ebs-storage-class.rendered)
#   }
# }
