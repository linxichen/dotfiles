if ! echo $PATH | grep -q /usr/local/MATLAB/R2014b/bin/glnxa64
then
	export PATH="/usr/local/MATLAB/R2014b/bin/glnxa64:$PATH"
fi
