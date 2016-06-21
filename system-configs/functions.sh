#!/bin/bash -xe

clone() {
  local project_name=$1
  local project_dir=$2

  git clone https://review.openstack.org/"$project_name" "$project_dir"
}

install_to_venv() {
  local project_dir=$1
  local venv_name=${2:-"venv"}
  local venv_path=$project_dir/$venv_name

  virtualenv $venv_path
  $venv_path/bin/pip install $project_dir
}
