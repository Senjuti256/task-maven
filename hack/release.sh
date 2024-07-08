#!/usr/bin/env bash
#
# Renders and copies documentation files into the informed RELEASE_DIR, the script search for
# task templates on a specific glob expression. The templates are rendered using the actual
# task name and documentation is searched for and copied over to the task release directory.
#

shopt -s inherit_errexit
set -eu -o pipefail

readonly RELEASE_DIR="${1:-}"

# Print error message and exit non-successfully.
panic() {
    echo "# ERROR: ${*}"
    exit 1
}

# Extracts the filename only, without path or extension.
extract_name() {
    declare filename=$(basename -- "${1}")
    declare extension="${filename##*.}"
    echo "${filename%.*}"
}

# Finds the respective documentation for the task name, however, for s2i it only consider the
# "task-s2i" part instead of the whole name.
find_doc() {
    declare task_name="${1}"
    [[ "${task_name}" == "task-s2i"* ]] &&
        task_name="task-s2i"
    find docs/ -name "${task_name}*.md"
}


# New function to handle StepActions
find_step_action_doc() {
    declare step_action_name="${1}"
    [[ "${step_action_name}" == "step-action-s2i"* ]] &&
        step_action_name="step-action-s2i"
    find docs/ -name "${step_action_name}*.md"
}


#
# Main
#

release() {
    # making sure the release directory exists, this script should only create releative
    # directories using it as root
    [[ ! -d "${RELEASE_DIR}" ]] &&
        panic "Release dir is not found '${RELEASE_DIR}'!"

    # See task-containers if there is more than one task to support.
    declare task_name=task-maven
    declare task_doc=README.md
    declare task_dir="${RELEASE_DIR}/tasks/${task_name}"
    [[ ! -d "${task_dir}" ]] &&
        mkdir -p "${task_dir}"

    # rendering the helm template for the specific file, using the resource name for the
    # filename respectively
    echo "# Rendering '${task_name}' at '${task_dir}'..."
    helm template . >${task_dir}/${task_name}.yaml ||
        panic "Unable to render '${task_name}'!"

    # finds the respective documentation file copying as "README.md", on the same
    # directory where the respective task is located
    echo "# Copying '${task_name}' documentation file '${task_doc}'..."
    cp -v -f ${task_doc} "${task_dir}/README.md" ||
        panic "Unable to copy '${task_doc}' into '${task_dir}'"


    
    # releasing all step action templates using the following glob expression
    for s in $(ls -1 templates/step-action-*.yaml); do
        declare step_action_name=$(extract_name ${s})
        [[ -z "${step_action_name}" ]] &&
            panic "Unable to extract StepAction name from '${s}'!"

        declare step_action_doc="$(find_step_action_doc ${step_action_name})"
        [[ -z "${step_action_doc}" ]] &&
            panic "Unable to find documentation file for '${step_action_name}'!"

        #declare step_action_dir="${RELEASE_DIR}/step-actions/${step_action_name}"
        #[[ ! -d "${step_action_dir}" ]] &&
         #   mkdir -p "${step_action_dir}"

        # rendering the helm template for the specific file, using the resource name for the
        # filename respectively
        echo "# Rendering '${step_action_name}' at '${task_dir}'..."
        helm template --show-only=${s} . >${task_dir}/${step_action_name}.yaml ||
            panic "Unable to render '${s}'!"

        # finds the respective documentation file copying as "README.md", on the same
        # directory where the respective step action is located
        echo "# Copying '${step_action_name}' documentation file '${step_action_doc}'..."
        cp -v -f ${step_action_doc} "${task_dir}/README.md" ||
            panic "Unable to copy '${step_action_doc}' into '${task_dir}'"
    done

    
}

release
