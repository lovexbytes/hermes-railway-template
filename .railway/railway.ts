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
    HOME: "/data",
  },
});

export default defineRailway(() =>
  project("hermes-railway-template", {
    resources: [hermes],
  }),
);