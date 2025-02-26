local env = {

  name = "santoku-http",
  version = "0.0.9-1",
  public = true,

  dependencies = {
    "lua == 5.1",
    "santoku >= 0.0.238-1",
    "santoku-system >= 0.0.31-1",
    "lua-cjson == 2.1.0.10-1",
    "luasocket == 3.1.0-1",
    "luasec == 1.3.2-1",
  },

  test = {
    dependencies = {
      "luacov >= 0.15.0-1",
    },
  }

}

env.homepage = "https://github.com/treadwelllane/lua-" .. env.name
env.tarball = env.name .. "-" .. env.version .. ".tar.gz"
env.download = env.homepage .. "/releases/download/" .. env.version .. "/" .. env.tarball

return {
  type = "lib",
  env = env,
}
