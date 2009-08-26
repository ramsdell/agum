# Haskell/Cabal Makefile
# Requires GNU Make
# The all target creates a default configuration if need be.

PACKAGE = agum
CONFIG	= dist/setup-config
SETUP	= runhaskell Setup.hs

all:	$(CONFIG)
	$(SETUP) build

Makefile:
	@echo make $@

$(PACKAGE).cabal:
	@echo make $@

$(CONFIG):	$(PACKAGE).cabal
	$(SETUP) configure --ghc --user --prefix="${HOME}"

%:	force
	$(SETUP) $@

.PHONY:	all force
