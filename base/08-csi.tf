locals {
  aws-ebs-csi-driver-url = "https://github.com/kubernetes-sigs/aws-ebs-csi-driver/releases/download/v${var.helm_release["aws-ebs-csi-driver"]}/helm-chart.tgz"
}

resource "helm_release" "aws-ebs-csi" {
  name = "aws-ebs-csi-driver"
  namespace = "kube-system"
  chart = "${local.aws-ebs-csi-driver-url}"
  version = "${var.helm_release["aws-ebs-csi-driver"]}"
  set {
    name = "enableVolumeScheduling"
    value = "true"
  }
  set {
    name = "enableVolumeResizing"
    value = "true"
  }
  set {
    name = "enableVolumeSnapshot"
    value = "true"
  }
}

data "template_file" "aws-ebs-storage-class" {
  template = <<EOF
kind: StorageClass
apiVersion: storage.k8s.io/v1
metadata:
  name: ebs
provisioner: ebs.csi.aws.com
volumeBindingMode: WaitForFirstConsumer
allowVolumeExpansion: true
---
apiVersion: snapshot.storage.k8s.io/v1alpha1
kind: VolumeSnapshotClass
metadata:
  name: ebs-snapshot
snapshotter: ebs.csi.aws.com
EOF
}

resource "null_resource" "aws-ebs-storage-class" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n kube-system apply -f -
${data.template_file.aws-ebs-storage-class.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    build_number = "${sha1(data.template_file.aws-ebs-storage-class.rendered)}"
  }
}

data "template_file" "aws-ebs-patch" {
  template = <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
bases:
- ../../base
images:
- name: amazon/aws-ebs-csi-driver
  newName: 602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/aws-ebs-csi-driver
  newTag: v0.4.0
- name: quay.io/k8scsi/csi-provisioner
  newName: 602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/csi-provisioner
  newTag: v1.3.0
- name: quay.io/k8scsi/csi-attacher
  newName: 602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/csi-attacher
  newTag: v1.2.0
- name: quay.io/k8scsi/livenessprobe
  newName: 602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/csi-liveness-probe
  newTag: v1.1.0
- name: quay.io/k8scsi/csi-node-driver-registrar
  newName: 602401143452.dkr.ecr.us-west-2.amazonaws.com/eks/csi-node-driver-registrar
  newTag: v1.1.0
EOF
}

resource "null_resource" "aws-ebs-patch" {
  provisioner "local-exec" {
    command = <<EOF
cat <<EOL | kubectl -n kube-system apply -k -
${data.template_file.aws-ebs-patch.rendered}
EOL
EOF
    environment {
      KUBECONFIG = "${var.kubeconfig_filename}"
    }
  }
  triggers {
    helm = "${helm_release.aws-ebs-csi.chart}"
    build_number = "${sha1(data.template_file.aws-ebs-patch.rendered)}"
  }
}
