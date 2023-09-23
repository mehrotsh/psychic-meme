Here's how they can include and use the reusable pipeline:

# .gitlab-ci.yml in some other project

include:
  - project: '<GROUP_NAME>/.gitlab'
    ref: master
    file: '/ci_templates/kaniko_build_publish.yml'

build_my_project_image:
  extends: .build_and_publish
  variables:
    DOCKERFILE_PATH: path/to/my/Dockerfile
    IMAGE_NAME: my-custom-image-name
    IMAGE_TAG: v1.0.0

