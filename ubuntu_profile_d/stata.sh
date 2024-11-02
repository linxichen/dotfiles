if ! echo $PATH | grep -q /usr/local/stata
then
	export PATH="/usr/local/stata:$PATH"
fi
