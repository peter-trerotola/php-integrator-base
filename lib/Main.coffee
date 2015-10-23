{Disposable} = require 'atom'

Parser               = require './Parser.coffee'
Utility              = require './Utility.coffee'
Service              = require './Service.coffee'
AtomConfig           = require './AtomConfig.coffee'
CachingProxy         = require './CachingProxy.coffee'
ConfigTester         = require './ConfigTester.coffee'
StatusBarProgressBar = require "./Widgets/StatusBarProgressBar.coffee"

module.exports =
    ###*
     * Configuration settings.
    ###
    config:
        phpCommand:
            title       : 'PHP command'
            description : 'The path to your PHP binary (e.g. /usr/bin/php, php, ...).'
            type        : 'string'
            default     : 'php'
            order       : 1

        composerCommand:
            title       : 'Composer command'
            description : 'The path to your Composer binary (e.g.: /usr/bin/composer, composer.phar, composer, ...).'
            type        : 'string'
            default     : 'composer'
            order       : 2

        autoloadScripts:
            title       : 'Path to autoloading script'
            description : 'The relative path to your autoloading script (usually autoload.php generated by composer).
                           Multiple comma-separated paths are supported, which will be tried in the specified order,
                           which is useful if you use different paths for different projects.'
            type        : 'array'
            default     : ['autoload.php', 'vendor/autoload.php']
            order       : 3

        classMapScripts:
            title       : 'Path to classmap script'
            description : 'The relative path to your class map (usually autoload_classmap.php generated by composer).
                           Multiple comma-separated paths are supported, which will be tried in the specified order,
                           which is useful if you use different paths for different projects.'
            type        : 'array'
            default     : ['vendor/composer/autoload_classmap.php', 'autoload/ezp_kernel.php']
            order       : 4

        insertNewlinesForUseStatements:
            title       : 'Insert newlines for use statements'
            description : 'When enabled, the plugin will add additional newlines before or after an automatically added
                           use statement when it can\'t add them nicely to an existing group. This results in more
                           cleanly separated use statements but will create additional vertical whitespace.'
            type        : 'boolean'
            default     : false
            order       : 5

    ###*
     * The name of the package.
    ###
    packageName: 'php-integrator-base'

    ###*
     * The config.
    ###
    config: null

    ###*
     * The exposed service.
    ###
    service: null

    ###*
     * The progress bar that is displayed during long operations.
    ###
    progressBar: null

    ###*
     * Tests the user's configuration.
     *
     * @return {boolean}
    ###
    testConfig: () ->
        configTester = new ConfigTester(@config)

        if not configTester.test()
            errorTitle = 'Incorrect setup!'
            errorMessage = 'Either PHP or Composer is not correctly set up and as a result PHP integrator will not ' +
              'work. Please visit the settings screen to correct this error. If you are not specifying an absolute ' +
              'path for PHP or Composer, make sure they are in your PATH.'

            atom.notifications.addError(errorTitle, {'detail': errorMessage})

            return false

        return true

    ###*
     * Registers any commands that are available to the user.
    ###
    registerCommands: () ->
        atom.commands.add 'atom-workspace', "php-integrator-base:configuration": =>
            return unless @testConfig()

            atom.notifications.addSuccess 'Success', {
                'detail' : 'Your PHP integrator configuration is working correctly!'
            }

    ###*
     * Registers listeners for config changes.
    ###
    registerConfigListeners: () ->
        @config.onDidChange 'php', () =>
            @service.clearCache()

        @config.onDidChange 'composer', () =>
            @service.clearCache()

        @config.onDidChange 'autoload', () =>
            @service.clearCache()

        @config.onDidChange 'classmap', () =>
            @service.clearCache()

    ###*
     * Performs a complete index of the current project.
    ###
    performFullIndex: () ->
        if @progressBar
            @progressBar.setLabel("Indexing...")
            @progressBar.show()

        @service.reindex null, () =>
            if @progressBar
                @progressBar.hide()

    ###*
     * Activates the package.
    ###
    activate: ->
        @config = new AtomConfig(@packageName)

        # See also atom-autocomplete-php pull request #197 - Disabled for now because it does not allow the user to
        # reactivate or try again.
        # return unless @testConfig()
        @testConfig()

        @progressBar = new StatusBarProgressBar()

        proxy = new CachingProxy(@config.get('php'))

        parser = new Parser(proxy)

        @service = new Service(proxy, parser)

        @registerCommands()
        @registerConfigListeners()

        @performFullIndex()

        atom.workspace.observeTextEditors (editor) =>
            editor.onDidSave (event) =>
                return unless editor.getGrammar().scopeName.match /text.html.php$/

                @service.clearCache()

                # For Windows - Replace \ in class namespace to / because
                # composer use / instead of \
                path = event.path

                for directory in atom.project.getDirectories()
                    if path.indexOf(directory.path) == 0
                        classPath = path.substr(0, directory.path.length+1)
                        path = path.substr(directory.path.length + 1)
                        break

                @service.reindex(classPath + Utility.normalizeSeparators(path))

    ###*
     * Deactivates the package.
    ###
    deactivate: ->

    ###*
     * Sets the status bar service, which is consumed by this package.
    ###
    setStatusBarService: (service) ->
        @progressBar.attach(service)

        return new Disposable => @progressBar.detach()

    ###*
     * Retrieves the service exposed by this package.
    ###
    getService: ->
        return @service
