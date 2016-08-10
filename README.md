# openshift-wlg

## Name
openshift-wlg - workload generation script for OpenShift

## Synopsis
workload-gen.sh [ARG]

## Description
OpenShift workload generator can automatically spawn pods to generate stress or jmeter load dynamically

### Arguments
**router**
	creates new projects containing pods which are routing JMeter traffic through an existing OpenShift router
**direct**
	injects new pods into existing projects which contain existing application pods to either generate stress or load
**clean**
	after the user has completed their testing and wants to discard the pods & projects that have been generated, clean-up
