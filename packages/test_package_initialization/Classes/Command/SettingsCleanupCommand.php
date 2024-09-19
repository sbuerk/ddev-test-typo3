<?php

declare(strict_types=1);

namespace DDEV\TestPackageInitialization\Command;

use Symfony\Component\Console\Attribute\AsCommand;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Input\InputInterface;
use Symfony\Component\Console\Output\OutputInterface;
use Symfony\Component\Console\Style\SymfonyStyle;
use TYPO3\CMS\Core\Configuration\ConfigurationManager;

#[AsCommand(name: 'settings:cleanup', description: 'Removes database credentials from system settings.')]
final class SettingsCleanupCommand extends Command
{
    public function __construct(
        private ConfigurationManager $configurationManager,
    ) {
        parent::__construct();
    }

    protected function execute(InputInterface $input, OutputInterface $output)
    {
        $io = new SymfonyStyle($input, $output);
        $settingsPath = $this->configurationManager->getSystemConfigurationFileLocation();
        if (!file_exists($settingsPath)) {
            $io->error(sprintf('Failed to clean not existing "%s".', $settingsPath));
            return Command::FAILURE;
        }

        $localConfiguration = $this->configurationManager->getLocalConfiguration();
        $defaultDatabaseConfiguration = $localConfiguration['DB']['Connections']['Default'] ?? [];
        if (!is_array($defaultDatabaseConfiguration) || $defaultDatabaseConfiguration === []) {
            $io->success('Nothing to clean');
            return Command::SUCCESS;
        }

        $newOptions = [];
        $allowedKeysForDefaultConnection = [
            'charset',
            'tableoptions',
            'defaultTableOptions',
        ];
        foreach ($defaultDatabaseConfiguration as $key => $value) {
            if (!in_array($key, $allowedKeysForDefaultConnection, true)) {
                // skip invalid default database configuration keys
                continue;
            }
            $newOptions[$key] = $value;
        }
        $localConfiguration['DB']['Connections']['Default'] = $newOptions;
        if (!$this->configurationManager->writeLocalConfiguration($localConfiguration)) {
            $io->error(sprintf('Failed to clean "%s".', $settingsPath));
            return Command::FAILURE;
        }
        $io->success(sprintf('Cleaned "%s".', $settingsPath));
        return Command::SUCCESS;
    }
}