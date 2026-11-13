BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\buckets.ps1"
}

Describe 'ConvertTo-BareGitHubUri' -Tag 'Scoop' {
    It 'unwraps mirror prefixes' {
        ConvertTo-BareGitHubUri 'https://gh-proxy.com/https://github.com/user/repo.git' | Should -Be 'https://github.com/user/repo.git'
        ConvertTo-BareGitHubUri 'https://gh-proxy.com/github.com/user/repo.git' | Should -Be 'https://github.com/user/repo.git'
        ConvertTo-BareGitHubUri 'https://a.com/https://b.com/github.com/user/repo.git' | Should -Be 'https://github.com/user/repo.git'
    }

    It 'ignores non-GitHub and non-http(s) URLs' {
        ConvertTo-BareGitHubUri 'https://github.com/user/repo.git' | Should -Be 'https://github.com/user/repo.git'
        ConvertTo-BareGitHubUri 'https://gitlab.com/user/repo.git' | Should -BeNullOrEmpty
        ConvertTo-BareGitHubUri 'git@github.com:user/repo.git' | Should -BeNullOrEmpty
        ConvertTo-BareGitHubUri '' | Should -BeNullOrEmpty
    }
}

Describe 'Convert-RepositoryUri' -Tag 'Scoop' {
    It 'passes local paths through unchanged' {
        Convert-RepositoryUri 'D:\Dropbox\mybucket' | Should -Be 'D:\Dropbox\mybucket'
        Convert-RepositoryUri 'D:/Dropbox/mybucket' | Should -Be 'D:/Dropbox/mybucket'
        Convert-RepositoryUri '\\nas\share\mybucket' | Should -Be '\\nas\share\mybucket'
        Convert-RepositoryUri 'file:///D:/mybucket' | Should -Be 'file:///D:/mybucket'
    }

    It 'still normalises GitHub URLs' {
        Convert-RepositoryUri 'https://github.com/ScoopInstaller/Extras.git' | Should -Be 'github.com/ScoopInstaller/Extras'
    }

    It 'still rejects URLs that are not git repos' {
        Convert-RepositoryUri 'definitely not a repo' | Should -BeNullOrEmpty
    }
}

Describe 'Sync-BucketRepository' -Tag 'Scoop' {
    BeforeEach {
        $script:calls = [System.Collections.Generic.List[string]]::new()
        $script:remote = 'https://github.com/ScoopInstaller/Extras.git'
        $script:exitCodes = [System.Collections.Generic.Queue[int]]::new()

        Mock Invoke-Git {
            $script:calls.Add($ArgumentList -join ' ')
            if ($ArgumentList[0] -eq 'config') { return $script:remote }
            if ($ArgumentList[0] -in @('-c', 'pull')) {
                $global:LASTEXITCODE = if ($script:exitCodes.Count) { $script:exitCodes.Dequeue() } else { 0 }
            }
        }
    }

    It 'pulls through github_proxy' {
        Mock get_config { 'https://mirror.example.com/' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }

        Sync-BucketRepository -Path 'T:\buckets\extras'

        $script:calls.Count | Should -Be 2
        $script:calls[1] | Should -Be '-c url.https://mirror.example.com/https://github.com/ScoopInstaller/Extras.git.insteadOf=https://github.com/ScoopInstaller/Extras.git pull -q'
    }

    It 'drops a stale mirror prefix when pulling through the proxy' {
        $script:remote = 'https://gh-proxy.com/https://github.com/ScoopInstaller/Extras.git'
        Mock get_config { 'https://mirror.example.com/' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }

        Sync-BucketRepository -Path 'T:\buckets\extras'

        $script:calls[1] | Should -Be '-c url.https://mirror.example.com/https://github.com/ScoopInstaller/Extras.git.insteadOf=https://gh-proxy.com/https://github.com/ScoopInstaller/Extras.git pull -q'
    }

    It 'falls back to the bare GitHub URL when the mirror fails' {
        $script:exitCodes.Enqueue(1)
        Mock get_config { 'https://mirror.example.com/' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }

        Sync-BucketRepository -Path 'T:\buckets\extras'

        $script:calls.Count | Should -Be 3
        $script:calls[2] | Should -Be 'pull -q'
    }

    It 'does not force direct GitHub when the remote already is the mirror' {
        $script:remote = 'https://mirror.example.com/https://github.com/ScoopInstaller/Extras.git'
        Mock get_config { 'https://mirror.example.com/' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }

        Sync-BucketRepository -Path 'T:\buckets\extras'

        $script:calls.Count | Should -Be 2
        $script:calls[1] | Should -Be 'pull -q'
    }

    It 'matches official Scoop when github_proxy is not configured' {
        $script:remote = 'https://gh-proxy.com/https://github.com/ScoopInstaller/Extras.git'
        Mock get_config { $null } -ParameterFilter { $name -eq 'GITHUB_PROXY' }

        Sync-BucketRepository -Path 'T:\buckets\extras'

        $script:calls.Count | Should -Be 2
        $script:calls[1] | Should -Be 'pull -q'
    }

    It 'leaves non-GitHub remotes alone' {
        $script:remote = 'https://gitlab.com/user/repo.git'
        Mock get_config { 'https://mirror.example.com/' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }

        Sync-BucketRepository -Path 'T:\buckets\extras'

        $script:calls.Count | Should -Be 2
        $script:calls[1] | Should -Be 'pull -q'
    }
}
