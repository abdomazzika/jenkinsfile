## RELEASE ####################################################################
define release
version=$(shell cat VERSION.json | egrep -o '[0-9]+\.[0-9]+\.[0-9]+');\
major=`echo $$version | cut -d'.' -f1 | sed 's/"//'`;\
minor=`echo $$version | cut -d'.' -f2 | sed 's/"//'`;\
patch=`echo $$version | cut -d'.' -f3 | sed 's/"//'`;\
\
case "$1" in \
	major) \
		echo "Bumping major version." \
		$$((major=$$major+1)) \
		$$((minor=0)) \
		$$((patch=0))\
		;; \
	minor) \
		echo "Bumping minor version." \
		$$((minor=$$minor+1)) \
		$$((patch=0))\
		;; \
	patch|*) \
		echo "Bumping patch version." \
		$$((patch=$$patch+1))\
		;; \
esac; \
\
NEXT_VERSION=$$major.$$minor.$$patch;\
echo "{ \"version\": \"$$NEXT_VERSION\" }" > VERSION.json;\
\
git commit -m "Version $$NEXT_VERSION" -- VERSION.json; \
git tag "$$NEXT_VERSION" -m "Version $$NEXT_VERSION";
endef

release-patch:
	@$(call release,patch)

release-minor:
	@$(call release,minor)

release-major:
	@$(call release,major)
push:
	git push --tags origin HEAD
