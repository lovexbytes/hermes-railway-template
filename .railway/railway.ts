import { defineRailway, project, service } from "railway/iac";

const hermes = service("hermes", {
  build: {
    builder: "DOCKERFILE",
  },
  deploy: {
    restartPolicyType: "ON_FAILURE",
    requiredMountPath: "/data",
  },
  env: {
    HERMES_HOME: "/data/.hermes",
    HERMES_IMAGE_VERSION: "latest",
    HERMES_WRITE_SAFE_ROOT: "/data",
    HERMES_LAZY_INSTALL_TARGET: "/data/.hermes/lazy-packages",
    HOME: "/data",
  },
});

export default defineRailway(() =>
  project("hermes-railway-template", {
    resources: [hermes],
  }),
);