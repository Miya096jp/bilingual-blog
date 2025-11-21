module.exports = {
  content: [
    "./public/*.html",
    "./app/helpers/**/*.rb",
    "./app/javascript/**/*.js",
    "./app/views/**/*.{erb,haml,html,slim}",
  ],
  corePlugins: {
    preflight: false,
  },
  plugins: [require("@tailwindcss/typography")],
};

// module.exports = {
//   plugins: [require("@tailwindcss/typography")],
// };
