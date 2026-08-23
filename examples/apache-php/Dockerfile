# Adaptation of vendor/awesome-compose/apache-php/app/Dockerfile for this pipeline.
#
# The vendored Dockerfile only builds a base php:8.0.9-apache "builder" stage and
# relies on docker-compose bind-mounting ./app onto /var/www/html at run time (a
# dev-only pattern: `docker build` alone produces an image with an empty docroot,
# which returns 403 Forbidden). Since our pipeline builds and minimizes a standalone
# image (no compose bind mount), we bake the application code in here, replicating
# what a real production build of this Dockerfile would need to do.
FROM php:8.0.9-apache AS builder

COPY app/ /var/www/html/

CMD ["apache2-foreground"]
