BeforeAll {
    . "$PSScriptRoot\Scoop-TestLib.ps1"
    . "$PSScriptRoot\..\lib\core.ps1"
    . "$PSScriptRoot\..\lib\download.ps1"
}

Describe 'Test-Aria2Enabled' -Tag 'Scoop' {
    It 'should return true if aria2 is installed' {
        Mock Test-HelperInstalled { $true }
        Mock get_config { $true }
        Test-Aria2Enabled | Should -BeTrue
    }

    It 'should return false if aria2 is not installed' {
        Mock Test-HelperInstalled { $false }
        Mock get_config { $false }
        Test-Aria2Enabled | Should -BeFalse

        Mock Test-HelperInstalled { $false }
        Mock get_config { $true }
        Test-Aria2Enabled | Should -BeFalse

        Mock Test-HelperInstalled { $true }
        Mock get_config { $false }
        Test-Aria2Enabled | Should -BeFalse
    }
}

Describe 'url_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_filename 'http://example.org/foo.txt' | Should -Be 'foo.txt'
        url_filename 'http://example.org/foo.txt?var=123' | Should -Be 'foo.txt'
    }

    It 'can be tricked with a hash to override the real filename' {
        url_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should -Be 'foo.zip'
    }
}

Describe 'url_remote_filename' -Tag 'Scoop' {
    It 'should extract the real filename from an url' {
        url_remote_filename 'http://example.org/foo.txt' | Should -Be 'foo.txt'
        url_remote_filename 'http://example.org/foo.txt?var=123' | Should -Be 'foo.txt'
    }

    It 'can not be tricked with a hash to override the real filename' {
        url_remote_filename 'http://example.org/foo-v2.zip#/foo.zip' | Should -Be 'foo-v2.zip'
    }
}

Describe 'Invoke-Download referer retry' -Tag 'Scoop' {
    It 'retries once without referer when the first attempt fails' {
        $script:attempts = @()
        Mock Invoke-DownloadOnce {
            $script:attempts += [bool] $NoReferer
            if (-not $NoReferer) { throw 'hotlink protected' }
        }
        { Invoke-Download 'https://example.com/a.zip' 'a.zip' $null $false } | Should -Not -Throw
        $script:attempts | Should -Be @($false, $true)
    }

    It 'does not retry when the first attempt succeeds' {
        $script:calls = 0
        Mock Invoke-DownloadOnce { $script:calls++ }
        Invoke-Download 'https://example.com/a.zip' 'a.zip' $null $false
        $script:calls | Should -Be 1
    }
}

Describe 'Rewrite-DownloadUrl' -Tag 'Scoop' {
    Context 'github_proxy is configured' {
        BeforeEach {
            Mock get_config { 'https://proxy/' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }
        }

        It 'rewrites github.com release download urls' {
            Rewrite-DownloadUrl 'https://github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://proxy/https://github.com/test/test/releases/download/a.zip'
        }

        It 'rewrites raw.githubusercontent.com urls' {
            Rewrite-DownloadUrl 'https://raw.githubusercontent.com/test/test/master/a.txt' |
                Should -Be 'https://proxy/https://raw.githubusercontent.com/test/test/master/a.txt'
        }

        It 'rewrites objects.githubusercontent.com urls' {
            Rewrite-DownloadUrl 'https://objects.githubusercontent.com/foo/bar' |
                Should -Be 'https://proxy/https://objects.githubusercontent.com/foo/bar'
        }

        It 'does not rewrite non-github urls' {
            Rewrite-DownloadUrl 'https://example.com/a.zip' | Should -Be 'https://example.com/a.zip'
        }

        It 'does not rewrite api.github.com urls' {
            Rewrite-DownloadUrl 'https://api.github.com/repos/test/test/releases/assets/1' |
                Should -Be 'https://api.github.com/repos/test/test/releases/assets/1'
        }

        It 'is idempotent (no double prefixing)' {
            $once = Rewrite-DownloadUrl 'https://github.com/test/test/releases/download/a.zip'
            Rewrite-DownloadUrl $once | Should -Be $once
        }

        It 'normalises a proxy prefix given without a trailing slash' {
            Mock get_config { 'https://proxy' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }
            Rewrite-DownloadUrl 'https://github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://proxy/https://github.com/test/test/releases/download/a.zip'
        }

        It 'unwraps a nested proxy with an https:// embedded github url' {
            Rewrite-DownloadUrl 'https://gh-proxy.com/https://github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://proxy/https://github.com/test/test/releases/download/a.zip'
        }

        It 'unwraps a nested proxy with an http:// embedded github url' {
            Rewrite-DownloadUrl 'https://gh-proxy.com/http://github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://proxy/https://github.com/test/test/releases/download/a.zip'
        }

        It 'unwraps a nested proxy with a schemeless embedded github url' {
            Rewrite-DownloadUrl 'https://gh-proxy.com/github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://proxy/https://github.com/test/test/releases/download/a.zip'
        }

        It 'unwraps a nested proxy wrapping raw.githubusercontent.com' {
            Rewrite-DownloadUrl 'https://gh-proxy.com/raw.githubusercontent.com/test/test/master/a.txt' |
                Should -Be 'https://proxy/https://raw.githubusercontent.com/test/test/master/a.txt'
        }

        It 'collapses multiply-nested proxies to a single prefix' {
            Rewrite-DownloadUrl 'https://a.com/https://b.com/github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://proxy/https://github.com/test/test/releases/download/a.zip'
        }
    }

    Context 'github_proxy is not configured' {
        It 'returns github urls unchanged when proxy is empty' {
            Mock get_config { '' } -ParameterFilter { $name -eq 'GITHUB_PROXY' }
            Rewrite-DownloadUrl 'https://github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://github.com/test/test/releases/download/a.zip'
        }

        It 'returns github urls unchanged when proxy is null' {
            Mock get_config { $null } -ParameterFilter { $name -eq 'GITHUB_PROXY' }
            Rewrite-DownloadUrl 'https://github.com/test/test/releases/download/a.zip' |
                Should -Be 'https://github.com/test/test/releases/download/a.zip'
        }
    }
}
