#!/bin/bash
#
# Launch stress generator pods on OpenShift clusters

###########################################################
# Embedded config for OpenShift ConfigMap, writes to file
# Globals:
#   None
# Arguments:
#   $1 - application to launch inside container
#   $2 - JMeter target hostname or IP address
#   $3 - Router IP address
# Returns:
#   None
###########################################################
write_config() {
  cat <<EOF > config.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: stress-config
data:
  to.run: "$1"
  stress.cpu: "6"
  stress.time: "44"
  jmeter.ip: "$2"
  jmeter.port: "80"
  router.ip: "$3"
EOF
}

# Shortcuts for a few oc commands
change_project() { oc project $1; }
delete_project() { oc delete project $1; }
new_project() { oc new-project stress-$1; }


###########################################################
# While loop to construct new load generating pods
# Globals:
#   None
# Arguments:
#   $1 - while loop query for routes or services
#   $2 - function to change or create project
#   $3 - router IP address (optional)
# Returns:
#   None
###########################################################
go_time() {
  while read -r line; do
    local namespace="$(echo "${line}" | cut -d' ' -f1)"
    local route="$(echo "${line}" | cut -d' ' -f2)"
    write_config "jmeter" "${route}" "$3"
    "$2" "${namespace}"
    oc create -f config.yaml
    oc create -f template-pod-cm.json
    oc new-app --template=alpine-stress-template
  done <<< "$1"
}

###########################################################
# Main function encapsulating case statement
# Globals:
#   None
# Arguments:
#   $1 - execution case
# Returns:
#   None
###########################################################
main() {
  case "${1:-router}" in
    router)
      change_project "default"
      local router_name="$(oc get pod | awk '/router/ {print $1;}')"
      local router_ip="$(oc describe pod "${router_name}" | grep IP | cut -c6-)"
      local loop_query="$(oc get route --all-namespaces --no-headers | awk '/example/ {print $1,$3;}')"
      go_time "${loop_query}" "new_project" "${router_ip}"
      ;;
    direct)
      local loop_query="$(oc get service --all-namespaces --no-headers | awk '/8080/ {print $1,$3;}')"
      go_time "${loop_query}" "change_project"
      ;;
    clean)
      local stress_project="$(oc get project | awk '/stress/ && /Active/ {print $1}')"
      local stress_pods="$(oc get pods --all-namespaces --no-headers | awk '/alpine-stress-/ && /Running/ {print $1,$2;}')"

      if [[ "${stress_project}" ]]; then
        while read -r line; do
          delete_project "${line}"
        done <<< "${stress_project}"
        echo "Deleted all stress projects."
      elif [[ "${stress_pods}" ]]; then
        while read -r line; do
          local namespace="$(echo "${line}" | cut -d' ' -f1)"
          local pod_name="$(echo "${line}" | cut -d' ' -f2)"
          change_project "${namespace}"
          oc delete pod "${pod_name}"
        done <<< "${stress_pods}"
        echo "Deleted all stress pods."
      else
        echo "Nothing to delete."
      fi
      ;;
    *)
      echo "$1? What are you even trying to do?"
  esac
}

main "$@"
