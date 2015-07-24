if ! echo $PATH | grep -q /usr/local/cuda-7.0/bin 
then
	export PATH="/usr/local/cuda-7.0/bin:$PATH"
fi
