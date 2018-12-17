/* Enable debug logging for Hub and user containers */

variable "debug" {
  description = "Enable debug logging"
  default = false
}

/* Start with variables for external access: 
    * hostname
    * TLS parameters
    * Application routes
*/

variable "hostname" {
  description = "Fully-qualified, externally-accessible (needed for OAUth callback), hostname of Jupyter endpoint"
}

variable "tls_dir" {
  description = "Local directory holding cert.pem, key.pem, chain.pem, and optionally dhparam.pem"
}

# How do I default these to be the filename appended to tls_dir if tls_dir is
#  set?

locals {
  # TLS files
  "tls_cert" = "${var.tls_dir}/cert.pem"
  "tls_key" = "${var.tls_dir}/key.pem"
  "tls_root_chain" = "${var.tls_dir}/chain.pem"
  "tls_dhparam" = "${var.tls_dir}/dhparam.pem"
}

variable "dhparam_bits" {
  description = "Size of DH parameters; only used if dhparam.pem is generated."
  default = 2048
}

variable "hub_route" {
  description = "Route to JupyterHub.  If it is '/', the landing page will not be installed; otherwise it will"
  default = "/nb/"
}

variable "firefly_route" {
  description = "Route to firefly.  If it is the empty string, firefly will not be installed"
  default = "/firefly/"
}

variable "oauth_provider" {
  description = "One of 'github' or 'cilogon'"
  default = "github"
}

/* Kubernetes parameters (derived from hostname) */

locals {
  "kubernetes_cluster_name" = "${replace(var.hostname,".","-")}"
  "_cluster_components" = "${split(".",var.hostname)}"
  "kubernetes_cluster_namespace" = "${local._cluster_components[0]}"
}

/* GKE parameters */

variable "gke_project" {
  description ="GKE project to install under"
}

variable "gke_region" {
  description = "GCE region of kubernetes nodes"
  default = "us-central1"
}

locals {
  "gke_zone" = "${var.gke_region}-a"
}

variable "gke_node_count" {
  description = "Number of kubernetes nodes in node pool"
  default = 3
}

variable "gke_machine_type" {
  description = "GCE Machine type for kubernetes nodes"
  default = "n1-standard-4"
}

variable "gke_default_local_volume_size_gigabytes" {
  description = "Node local volume size (mostly for image cache)"
  default = 200
}

/* Fileserver parameters */

# If set, external fileserver is used

variable "external_fileserver_ip" {
  description = "IP of NFS server; must be accessible from Hub, Firefly, and JupyterLab"
  default = ""
}

variable "volume_size_gigabytes" {
  description = "Size of fileserver exported volume in gigabytes.  Note that GKE caps the volume size at 500 unless you ask for the limits to be raised"
  default = 20
}

/* OAuth parameters */

variable "oauth_client_id" {
  description = "Client ID to use for OAuth authentication"
}

variable "oauth_secret" {
  description = "OAuth secret for authentication"
}

variable "allowed_groups" {
  description = "List of groups allowed to use Jupyter"
}

# We have both of these in preparation for chained authentication flows.

locals {
  "github_allowed_organizations" = "${var.oauth_provider == "github" ? var.allowed_groups : "dummy" }"
  "cilogon_allowed_groups" = "${var.oauth_provider == "cilogon" ? var.allowed_groups : "dummy" }"
}

variable "forbidden_groups" {
  description = "List of groups forbidden from using Jupyter"
}

locals {
  "github_forbidden_organizations" = "${var.oauth_provider == "github" ? var.forbidden_groups : "dummy" }"
  "cilogon_forbidden_groups" = "${var.oauth_provider == "cilogon" ? var.forbidden_groups : "dummy" }"
}

/* Session Database params */

variable "session_db_url" {
  description = "session storage location; any SQLAlchemy URL will work"
  default = "sqlite:////home/jupyter/jupyterhub.sqlite"
}

/* Automatically refreshed repositories */

variable "auto_repo_urls" {
  description = "Repositories to be checked out automatically at lab start"
  default = [ "https://github.com/lsst-sqre/notebook-demo" ]
}

/* Enable Dask */

variable "allow_dask_containers" {
  description = "Allow users to spawn dask workers"
  default = true
}

/* Prepuller image parameters */

variable "prepuller_repo" {
  description = "Hostname of image repository"
  default = "hub.docker.com"
}

variable "prepuller_owner" {
  description = "Owner of image repository"
  default = "lsstsqre"
}

variable "prepuller_image_name" {
  description = "Name of prepulled image"
  default = "jld-lab"
}

/* These control number of daily/weekly/release images to prepull.
   This requires a tag format like LSST/DM uses. */

variable "prepuller_dailies" {
  description = "Number of daily images to prepull"
  default = 3
}

variable "prepuller_weekies" {
  description = "Number of weekly images to prepull"
  default = 2
}

variable "prepuller_releases" {
  description = "Number of release images to prepull"
  default = 1
}

/* For private Docker repos, maybe you need to set the port or turn off TLS. */

variable "prepuller_port" {
  description = "Port number on image repository"
  default = "443"
}

variable "prepuller_insecure" {
  description = "Disable TLS on repository pull?"
  default = false
}

/* Probably do not need to change these. */
variable "prepuller_sort_field" {
  description = "Field to sort prepuller images by"
  default = "comp_ts"
}

variable "prepuller_command" {
  description = "Command to run in prepulled image container"
  default = "echo \"Prepuller complete on $(hostname) at $(date)\""
}

locals {
  prepuller_namespace = "${local.kubernetes_cluster_namespace}"
}

/* Parameters for images presented in the Hub menu
   Unless you are trying to annoy your users, these should probably match
   the values above. */

/* If you only want a single lab image, set lab_image, e.g.
   "lsstsqre/jld-lab:latest" */

variable "lab_image" {
  description = "Single image for presenting"
  default =""
}

/* As with the prepuller, if you want to scan a repo for tags... */

locals {
  "lab_repo_host" = "${var.prepuller_repo}"
  "lab_repo_owner" = "${var.prepuller_owner}"
  "lab_repo_name" = "${var.prepuller_image_name}"
}

/* Image size parameters

   By default you get four image sizes, "tiny", "small", "medium", and
   "large".  Each one is twice the size (memory and CPU) of the previous
   one.  The size range specifies that (except for tiny, which has an
   extremely minimal guarantee) the guaranteed memory and CPU are
   1/lab_size_range, so if you ask for, e.g., 2 CPU and 4096 MB you are
   guaranteed you get at least half a CPU and 1024 MB reseved, and can
   allocate up to 2 CPU/4096 MB.  By default the second smallest one is
   preselected.

*/

variable "tiny_max_cpu" {
  description = "Maximum CPU core-equivalents for \"tiny\" container"
  default=0.5
}

variable "mb_per_cpu" {
  description = "Ratio of megabytes to cores in containers"
  default = 2048
}

variable "lab_size_range" {
  description = "Ratio of maximum to initially-requested container resources"
  default = 4.0
}

variable "size_index" {
  description = "Index of default size (usually range of 0-3)"
  default = 1
}

/* Node.js memory size */

variable "lab_nodejs_max_mem" {
  description = "Maximum size in megabytes that node.js can consume"
  default = 4096
}

/* Idle timeout for reaping user containers */

variable "lab_idle_timeout" {
  description = "Time in seconds before idle container is reaped"
  default = 43200
}

/* Restrict nodes */

variable "restrict_lab_nodes" {
  description = "Spawn Lab containers only on nodes with \"jupyterlab: ok\" labels"
  default = false
}

variable "restrict_dask_nodes" {
  description = "Spawn Dask containers only on nodes with \"dask: ok\" labels"
  default = false
}

variable "restrict_firefly_nodes" {
  description = "Spawn Firefly containers only on nodes with \"firefly: ok\" labels"
  default = false
}

variable "restrict_infrastructure_nodes" {
  description = "Spawn infrastructure (Hub, fileserver, ELK) containers only on nodes with \"infrastructure: ok\" labels"
  default = false
}

/* Optional variables for ELK logging.  Set enable_elk true to enable. */

variable "enable_elk" {
  description = "Enable ELK logging via filebeat/shovel/rabbitmq"
  default = false
}


locals {
  "beats_cert" = "${var.tls_dir}/beat_cert.pem" 
  "beats_ca" = "${var.tls_dir}/beat_ca.pem"
  "beats_key" = "${var.tls_dir}/beat_key.pem"
  "shipper_name" = "${local.kubernetes_cluster_namespace}"
  "rabbitmq_pan_password" = "changeme"
  "rabbitmq_target_host" = "rabbitmq"
  "rabbitmq_target_vhost" = "${local.kubernetes_cluster_namespace}"
}

/* Optional variables for firefly.  Set replicas > 0 to enable */

variable "firefly_admin_password" {
  description = "Firefly administrative password"
  default = ""
}

variable "firefly_replicas" {
  description = "Number of Firefly containers"
  default = 0
}

variable "firefly_max_jvm_size" {
  description = "Maximum JVM size for Firefly"
  default = "8064M"
}

variable "firefly_container_mem_limit" {
  description = "Maximum container size for Firefly"
  default = "8192M"
}

variable "firefly_container_cpu_limit" {
  description = "Maximum number of CPU cores for Firefly container"
  default = 3.0
}

variable "firefly_container_uid" {
  description = "UID under which to run Firefly"
  default = 91
}
