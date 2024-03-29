#!/bin/bash

# Package name
package_name="lst"

# Default installation path
default_install_dir_path="$HOME/.local/share"

# Default binary path
default_bin_dir_path="$HOME/.local/bin"

# Entry point for the script
entry_point="lst.py"

# GitHub repository URL for cloning
github_repo="https://github.com/byomess/lst.git"

# Default Python version for running the package
TARGET_PYENV_PYTHON_VERSION="3.11"

silent=false
no_confirmation=false
clone_repo=false

for arg in "$@"; do
	case $arg in
	--silent)
		silent=true
		shift
		;;
	--no-confirmation)
		no_confirmation=true
		shift
		;;
	--clone)
		clone_repo=true
		no_confirmation=true
		shift
		;;
	--path=*)
		custom_install_dir_path="${arg#*=}"
		shift
		;;
	--bin-path=*)
		custom_bin_dir_path="${arg#*=}"
		shift
		;;
	esac
done

install_dir_path="${custom_install_dir_path:-$default_install_dir_path}"
bin_dir_path="${custom_bin_dir_path:-$default_bin_dir_path}"
bin_link_path="$bin_dir_path/$package_name"

package_install_dir_path="$install_dir_path/$package_name"
package_entry_point_path="$package_install_dir_path/$entry_point"
package_bin_path="$package_install_dir_path/$package_name"
package_python_bin_path="$package_install_dir_path/venv/bin/python"

# Function to echo only if not in silent mode
echo_if_not_silent() {
	if [[ "$silent" == false ]]; then
		echo "$@"
	fi
}

generate_entry_point_script() {
	cat <<EOF >"$package_bin_path"
#!/bin/bash
"$package_python_bin_path" "$package_entry_point_path" "\$@"
EOF

	chmod +x "$package_bin_path"
}

# Modified installation steps
perform_installation() {
	echo_if_not_silent "Installing $package_name at '$package_install_dir_path'."
	mkdir -p "$install_dir_path"
	cp -r . "$package_install_dir_path"
	generate_entry_point_script
	ln -s "$package_bin_path" "$bin_link_path"
}

# Update PATH
update_path_in_shell() {
	local PATH_includes_bin_dir_path=false

	# Check if the path is already in the PATH
	if echo "$PATH" | grep -q "$(cd $bin_dir_path && pwd)"; then
		PATH_includes_bin_dir_path=true
	fi

	if [ "$PATH_includes_bin_dir_path" = true ]; then
		echo_if_not_silent "$bin_dir_path is already in your PATH."
		return
	fi

	if [[ $no_confirmation == false ]]; then
		echo "$bin_dir_path is not in your PATH."
		echo "You are using the $SHELL shell."
		read -p "Do you want to automatically add $HOME/.local/bin to your PATH? (y/N) " -n 1 -r

		if [[ ! $REPLY =~ ^[Yy]$ ]]; then
			echo_if_not_silent "Please add $HOME/.local/bin to your PATH manually."
			return
		fi
	fi

	local shell_config_file
	case "$SHELL" in
	*/bash)
		shell_config_file="$HOME/.bashrc"
		;;
	*/zsh)
		shell_config_file="$HOME/.zshrc"
		;;
	*/fish)
		shell_config_file="$HOME/.config/fish/config.fish"
		;;
	*)
		echo "Unsupported shell for automatic PATH update. Please manually add $bin_dir_path to your PATH."
		return
		;;
	esac

	echo "export PATH=\"$bin_dir_path:\$PATH\"" >>"$shell_config_file"

	echo_if_not_silent "Added $bin_dir_path to PATH in $shell_config_file."
}

# Check if already installed and prompt for reinstallation
check_existing_installation() {
	if [ -d "$package_install_dir_path" ]; then
		if [[ "$no_confirmation" == false ]]; then
			read -p "$package_name is already installed. Do you want to proceed with reinstallation? (y/n) " -n 1 -r
			if [[ ! $REPLY =~ ^[Yy]$ ]]; then
				echo_if_not_silent "Installation cancelled."
				exit 0
			fi
		fi
		rm -rf "$package_install_dir_path"
		rm -f "$bin_link_path"
	fi
}

clone_repo_and_setup() {
	if [[ "$clone_repo" == true ]]; then
		git clone "$github_repo"
		cd "$package_name" || exit
		./setup.sh
	fi
}

remove_repository() {
	if [[ "$clone_repo" == true ]]; then
		cd ..
		rm -rf "$package_name"
		echo_if_not_silent "Removed the cloned repository."
	fi
}

main() {
	check_existing_installation
	clone_repo_and_setup
	perform_installation
	generate_entry_point_script
	update_path_in_shell
	remove_repository
	echo_if_not_silent "Installation completed."
}

main "$@"
