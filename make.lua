local env = {

  name = "santoku-http",
  version = "0.0.20-1",
  license = "MIT",
  public = true,

  dependencies = {
    "lua == 5.1",
    "santoku >= 0.0.314-1",
  },


}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return {

  env = env,
}
