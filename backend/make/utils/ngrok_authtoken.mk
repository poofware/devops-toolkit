# ---------------------------------------
# Ngrok authtoken for local development
#
# These constants are not sensitive, and hence, are made available for Poof backend services.
# ---------------------------------------

SHELL := /bin/bash


# ---------------------------------
# Internal Variable Declaration
# ---------------------------------

ifndef NGROK_AUTHTOKEN
  export NGROK_AUTHTOKEN := 2whJdsbLfd2hSZxeYJqoWyMkBRK_4oxi113BZQkFuHApSfNek
endif


INCLUDED_NGROK_AUTHTOKEN := 1
