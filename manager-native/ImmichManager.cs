using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Linq;
using System.Net.Sockets;
using System.Text;
using System.Threading.Tasks;
using System.Windows.Forms;

namespace ImmichWindowsManager
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            Application.Run(new MainForm());
        }
    }

    internal sealed class ComponentInfo
    {
        public string Id;
        public string Name;
        public int Port;
        public string Description;
    }

    internal sealed class MainForm : Form
    {
        private readonly string repoRoot;
        private readonly string runtimeDir;
        private readonly string logsDir;
        private readonly string dataDir;
        private readonly string postgresDataDir;
        private readonly string redisDataDir;
        private readonly string uploadDir;
        private readonly string buildDir;
        private readonly string modelDir;
        private readonly Dictionary<string, ComponentInfo> components;
        private readonly Dictionary<string, Process> managedProcesses = new Dictionary<string, Process>();
        private readonly Dictionary<string, Label> statusLabels = new Dictionary<string, Label>();
        private readonly Dictionary<string, Button> startButtons = new Dictionary<string, Button>();
        private readonly Dictionary<string, Button> stopButtons = new Dictionary<string, Button>();
        private readonly HashSet<string> busyComponents = new HashSet<string>();
        private readonly Timer statusTimer = new Timer();
        private readonly TextBox logBox = new TextBox();
        private readonly Label logTitle = new Label();
        private string selectedComponent = "postgres";

        public MainForm()
        {
            repoRoot = ResolveRepoRoot();
            runtimeDir = Path.Combine(repoRoot, "runtime");
            logsDir = Path.Combine(runtimeDir, "logs");
            dataDir = Path.Combine(runtimeDir, "data");
            postgresDataDir = Path.Combine(dataDir, "postgres");
            redisDataDir = Path.Combine(dataDir, "redis");
            uploadDir = Path.Combine(repoRoot, "upload");
            buildDir = Path.Combine(repoRoot, "build");
            modelDir = Path.Combine(runtimeDir, "models");

            components = new Dictionary<string, ComponentInfo>();
            components.Add("postgres", new ComponentInfo { Id = "postgres", Name = "PostgreSQL", Port = 54329, Description = "内置数据库，自动初始化并启用 pgvector。" });
            components.Add("redis", new ComponentInfo { Id = "redis", Name = "Redis", Port = 63790, Description = "内置缓存和队列组件。" });
            components.Add("ml", new ComponentInfo { Id = "ml", Name = "Machine Learning", Port = 3003, Description = "机器学习服务，模型首次使用时自动下载。" });
            components.Add("server", new ComponentInfo { Id = "server", Name = "Immich Server", Port = 2283, Description = "Immich 服务端 API 和 Web 页面。" });

            EnsureDirectories();
            BuildUi();
            statusTimer.Interval = 2500;
            statusTimer.Tick += async (sender, args) => await RefreshStatusAsync();
            statusTimer.Start();
            Shown += async (sender, args) =>
            {
                await RefreshStatusAsync();
                LoadLog(selectedComponent);
            };
        }

        private static string ResolveRepoRoot()
        {
            var dir = AppDomain.CurrentDomain.BaseDirectory;
            while (!string.IsNullOrEmpty(dir))
            {
                if (Directory.Exists(Path.Combine(dir, "runtime")) && Directory.Exists(Path.Combine(dir, "server")))
                {
                    return dir.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
                }
                var parent = Directory.GetParent(dir);
                dir = parent == null ? null : parent.FullName;
            }
            return AppDomain.CurrentDomain.BaseDirectory.TrimEnd(Path.DirectorySeparatorChar, Path.AltDirectorySeparatorChar);
        }

        private void EnsureDirectories()
        {
            foreach (var dir in new[] { runtimeDir, logsDir, dataDir, postgresDataDir, redisDataDir, uploadDir, modelDir })
            {
                Directory.CreateDirectory(dir);
            }
        }

        private void BuildUi()
        {
            Text = "Immich Manager";
            MinimumSize = new Size(1000, 640);
            Size = new Size(1160, 720);
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Microsoft YaHei UI", 9F);
            BackColor = Color.FromArgb(246, 247, 249);

            var root = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 2,
                ColumnCount = 1,
            };
            root.RowStyles.Add(new RowStyle(SizeType.Absolute, 88));
            root.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            Controls.Add(root);

            var top = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(22, 14, 22, 12),
                BackColor = Color.White,
                ColumnCount = 2,
            };
            top.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            top.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 430));
            root.Controls.Add(top, 0, 0);

            var titlePanel = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.TopDown, WrapContents = false };
            var title = new Label { Text = "Immich Manager", AutoSize = true, Font = new Font(Font.FontFamily, 16F, FontStyle.Bold) };
            var repo = new Label { Text = repoRoot, AutoSize = true, ForeColor = Color.FromArgb(88, 99, 114), Margin = new Padding(0, 6, 0, 0) };
            titlePanel.Controls.Add(title);
            titlePanel.Controls.Add(repo);
            top.Controls.Add(titlePanel, 0, 0);

            var topButtons = new FlowLayoutPanel { Dock = DockStyle.Fill, FlowDirection = FlowDirection.RightToLeft, WrapContents = false };
            topButtons.Controls.Add(MakeButton("打开 Immich", async () => await OpenImmichAsync(), false));
            topButtons.Controls.Add(MakeButton("停止全部", async () => await StopAllAsync(), false));
            topButtons.Controls.Add(MakeButton("启动全部", async () => await StartAllAsync(), true));
            top.Controls.Add(topButtons, 1, 0);

            var main = new SplitContainer
            {
                Dock = DockStyle.Fill,
                SplitterDistance = 530,
                BackColor = Color.FromArgb(217, 224, 232),
            };
            root.Controls.Add(main, 0, 1);

            var cards = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                Padding = new Padding(18),
                ColumnCount = 2,
                RowCount = 2,
                BackColor = Color.FromArgb(246, 247, 249),
            };
            cards.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            cards.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 50));
            cards.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            cards.RowStyles.Add(new RowStyle(SizeType.Percent, 50));
            main.Panel1.Controls.Add(cards);

            var index = 0;
            foreach (var id in new[] { "postgres", "redis", "ml", "server" })
            {
                cards.Controls.Add(MakeCard(components[id]), index % 2, index / 2);
                index++;
            }

            var logPanel = new TableLayoutPanel
            {
                Dock = DockStyle.Fill,
                RowCount = 2,
                BackColor = Color.FromArgb(16, 24, 32),
            };
            logPanel.RowStyles.Add(new RowStyle(SizeType.Absolute, 70));
            logPanel.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            main.Panel2.Controls.Add(logPanel);

            var logHeader = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2, Padding = new Padding(16, 12, 16, 10), BackColor = Color.FromArgb(16, 24, 32) };
            logHeader.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            logHeader.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 92));
            logTitle.Text = "PostgreSQL 日志";
            logTitle.ForeColor = Color.FromArgb(222, 233, 244);
            logTitle.Font = new Font(Font.FontFamily, 12F, FontStyle.Bold);
            logTitle.Dock = DockStyle.Fill;
            logHeader.Controls.Add(logTitle, 0, 0);
            logHeader.Controls.Add(MakeButton("刷新", async () => { LoadLog(selectedComponent); await RefreshStatusAsync(); }, false), 1, 0);
            logPanel.Controls.Add(logHeader, 0, 0);

            logBox.Dock = DockStyle.Fill;
            logBox.Multiline = true;
            logBox.ScrollBars = ScrollBars.Both;
            logBox.ReadOnly = true;
            logBox.WordWrap = false;
            logBox.BackColor = Color.FromArgb(11, 18, 25);
            logBox.ForeColor = Color.FromArgb(220, 231, 242);
            logBox.BorderStyle = BorderStyle.None;
            logBox.Font = new Font("Consolas", 9F);
            logPanel.Controls.Add(logBox, 0, 1);
        }

        private Control MakeCard(ComponentInfo component)
        {
            var card = new Panel
            {
                Dock = DockStyle.Fill,
                Margin = new Padding(6),
                Padding = new Padding(14),
                BackColor = Color.White,
                BorderStyle = BorderStyle.FixedSingle,
            };
            card.Click += (sender, args) => SelectComponent(component.Id);

            var layout = new TableLayoutPanel { Dock = DockStyle.Fill, RowCount = 4, ColumnCount = 1 };
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 52));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 54));
            layout.RowStyles.Add(new RowStyle(SizeType.Absolute, 46));
            layout.RowStyles.Add(new RowStyle(SizeType.Percent, 100));
            card.Controls.Add(layout);

            var head = new TableLayoutPanel { Dock = DockStyle.Fill, ColumnCount = 2 };
            head.ColumnStyles.Add(new ColumnStyle(SizeType.Percent, 100));
            head.ColumnStyles.Add(new ColumnStyle(SizeType.Absolute, 92));
            var name = new Label { Text = component.Name, Dock = DockStyle.Fill, Font = new Font(Font.FontFamily, 11F, FontStyle.Bold) };
            statusLabels[component.Id] = new Label { Text = "检查中", Dock = DockStyle.Fill, TextAlign = ContentAlignment.MiddleRight, ForeColor = Color.FromArgb(88, 99, 114) };
            head.Controls.Add(name, 0, 0);
            head.Controls.Add(statusLabels[component.Id], 1, 0);
            layout.Controls.Add(head, 0, 0);

            layout.Controls.Add(new Label
            {
                Text = "127.0.0.1:" + component.Port + "\r\n" + component.Description,
                Dock = DockStyle.Fill,
                ForeColor = Color.FromArgb(88, 99, 114),
            }, 0, 1);

            var actions = new FlowLayoutPanel { Dock = DockStyle.Fill, WrapContents = false };
            startButtons[component.Id] = MakeButton("启动", async () => await RunComponentBusyAsync(component.Id, () => StartComponentAsync(component.Id)), true);
            stopButtons[component.Id] = MakeButton("停止", async () => await RunComponentBusyAsync(component.Id, () => StopComponentAsync(component.Id)), false);
            actions.Controls.Add(startButtons[component.Id]);
            actions.Controls.Add(stopButtons[component.Id]);
            actions.Controls.Add(MakeButton("日志", async () => { SelectComponent(component.Id); await RefreshStatusAsync(); }, false));
            layout.Controls.Add(actions, 0, 2);

            return card;
        }

        private Button MakeButton(string text, Func<Task> action, bool primary)
        {
            var button = new Button
            {
                Text = text,
                Width = 92,
                Height = 34,
                FlatStyle = FlatStyle.Flat,
                BackColor = primary ? Color.FromArgb(18, 109, 141) : Color.White,
                ForeColor = primary ? Color.White : Color.FromArgb(29, 36, 48),
                Margin = new Padding(4),
            };
            button.FlatAppearance.BorderColor = primary ? Color.FromArgb(18, 109, 141) : Color.FromArgb(201, 210, 223);
            button.Click += async (sender, args) => await action();
            return button;
        }

        private async Task RunComponentBusyAsync(string componentId, Func<Task> action)
        {
            if (busyComponents.Contains(componentId)) return;
            busyComponents.Add(componentId);
            await RefreshStatusAsync();
            try
            {
                await action();
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Immich Manager", MessageBoxButtons.OK, MessageBoxIcon.Error);
                AppendLog(componentId, "[manager] ERROR: " + ex.Message + Environment.NewLine);
            }
            finally
            {
                busyComponents.Remove(componentId);
            }
            await RefreshStatusAsync();
            LoadLog(selectedComponent);
        }

        private static IEnumerable<Control> GetAllControls(Control parent)
        {
            foreach (Control child in parent.Controls)
            {
                yield return child;
                foreach (var nested in GetAllControls(child)) yield return nested;
            }
        }

        private void SelectComponent(string componentId)
        {
            selectedComponent = componentId;
            logTitle.Text = components[componentId].Name + " 日志";
            LoadLog(componentId);
        }

        private async Task RefreshStatusAsync()
        {
            foreach (var component in components.Values)
            {
                var running = await IsPortOpenAsync(component.Port);
                var isBusy = busyComponents.Contains(component.Id);
                statusLabels[component.Id].Text = running ? "运行中" : "已停止";
                if (isBusy) statusLabels[component.Id].Text = "处理中";
                statusLabels[component.Id].ForeColor = running ? Color.FromArgb(30, 155, 98) : Color.FromArgb(120, 130, 143);
                startButtons[component.Id].Enabled = !isBusy && !running;
                stopButtons[component.Id].Enabled = !isBusy && running;
            }
        }

        private Dictionary<string, string> BuildEnvironment()
        {
            var values = new Dictionary<string, string>();
            values.Add("IMMICH_ENV", "development");
            values.Add("IMMICH_HOST", "127.0.0.1");
            values.Add("IMMICH_PORT", "2283");
            values.Add("IMMICH_BUILD_DATA", buildDir);
            values.Add("IMMICH_MEDIA_LOCATION", uploadDir);
            values.Add("IMMICH_MACHINE_LEARNING_URL", "http://127.0.0.1:3003");
            values.Add("IMMICH_IGNORE_MOUNT_CHECK_ERRORS", "true");
            values.Add("IMMICH_RUNTIME_DIR", runtimeDir);
            values.Add("IMMICH_POSTGRES_BIN", Path.Combine(runtimeDir, "postgres", "bin"));
            values.Add("IMMICH_POSTGRES_DATA", postgresDataDir);
            values.Add("IMMICH_REDIS_BIN", Path.Combine(runtimeDir, "redis"));
            values.Add("IMMICH_REDIS_DATA", redisDataDir);
            values.Add("IMMICH_POSTGRES_PORT", "54329");
            values.Add("IMMICH_REDIS_PORT", "63790");
            values.Add("DB_URL", "postgres://postgres:postgres@127.0.0.1:54329/immich");
            values.Add("DB_VECTOR_EXTENSION", "pgvector");
            values.Add("REDIS_HOSTNAME", "127.0.0.1");
            values.Add("REDIS_PORT", "63790");
            values.Add("MACHINE_LEARNING_CACHE_FOLDER", modelDir);
            values.Add("MACHINE_LEARNING_HOST", "127.0.0.1");
            values.Add("MACHINE_LEARNING_PORT", "3003");
            values.Add("MACHINE_LEARNING_WORKERS", "1");
            values.Add("HF_HOME", Path.Combine(runtimeDir, "hf-home"));
            values.Add("PGPASSWORD", "postgres");
            values.Add("PATH", Path.Combine(runtimeDir, "node", "node-v22.20.0-win-x64") + ";" + Path.Combine(runtimeDir, "tools", "uv") + ";" + Path.Combine(runtimeDir, "tools", "binaryen", "bin") + ";" + Environment.GetEnvironmentVariable("PATH"));
            return values;
        }

        private async Task StartComponentAsync(string componentId)
        {
            if (componentId == "postgres") await StartPostgresAsync();
            if (componentId == "redis") await StartRedisAsync();
            if (componentId == "ml") await StartMachineLearningAsync();
            if (componentId == "server") await StartServerAsync();
        }

        private async Task StopComponentAsync(string componentId)
        {
            if (componentId == "server") await StopTrackedOrPortAsync("server", 2283);
            if (componentId == "ml") await StopTrackedOrPortAsync("ml", 3003);
            if (componentId == "redis") await StopRedisAsync();
            if (componentId == "postgres") await StopPostgresAsync();
        }

        private async Task StartAllAsync()
        {
            foreach (var id in components.Keys) busyComponents.Add(id);
            await RefreshStatusAsync();
            try
            {
                await StartPostgresAsync();
                await StartRedisAsync();
                await StartMachineLearningAsync();
                await StartServerAsync();
                SelectComponent("server");
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Immich Manager", MessageBoxButtons.OK, MessageBoxIcon.Error);
                AppendLog(selectedComponent, "[manager] ERROR: " + ex.Message + Environment.NewLine);
            }
            finally
            {
                busyComponents.Clear();
            }
            await RefreshStatusAsync();
            LoadLog(selectedComponent);
        }

        private async Task StopAllAsync()
        {
            foreach (var id in components.Keys) busyComponents.Add(id);
            await RefreshStatusAsync();
            try
            {
                await StopTrackedOrPortAsync("server", 2283);
                await StopTrackedOrPortAsync("ml", 3003);
                await StopRedisAsync();
                await StopPostgresAsync();
            }
            catch (Exception ex)
            {
                MessageBox.Show(this, ex.Message, "Immich Manager", MessageBoxButtons.OK, MessageBoxIcon.Error);
                AppendLog(selectedComponent, "[manager] ERROR: " + ex.Message + Environment.NewLine);
            }
            finally
            {
                busyComponents.Clear();
            }
            await RefreshStatusAsync();
            LoadLog(selectedComponent);
        }

        private async Task OpenImmichAsync()
        {
            await Task.Run(() => Process.Start("http://127.0.0.1:2283"));
        }

        private async Task StartPostgresAsync()
        {
            var bin = Path.Combine(runtimeDir, "postgres", "bin");
            var initDb = Path.Combine(bin, "initdb.exe");
            var pgCtl = Path.Combine(bin, "pg_ctl.exe");
            var createdb = Path.Combine(bin, "createdb.exe");
            var psql = Path.Combine(bin, "psql.exe");
            AssertFile(Path.Combine(bin, "postgres.exe"), "缺少内置 PostgreSQL");
            AssertFile(initDb, "PostgreSQL 不完整");
            AssertFile(pgCtl, "PostgreSQL 不完整");
            AssertFile(createdb, "PostgreSQL 不完整");
            AssertFile(psql, "PostgreSQL 不完整");
            AssertFile(Path.Combine(runtimeDir, "postgres", "share", "extension", "vector.control"), "缺少 pgvector 扩展");

            if (!File.Exists(Path.Combine(postgresDataDir, "PG_VERSION")))
            {
                AppendLog("postgres", "[manager] initializing PostgreSQL data directory" + Environment.NewLine);
                await RunProcessAsync("postgres", initDb, "-D " + Quote(postgresDataDir) + " -U postgres --encoding=UTF8 --locale=C", repoRoot);
            }

            if (!await IsPortOpenAsync(54329))
            {
                AppendLog("postgres", "[manager] starting PostgreSQL" + Environment.NewLine);
                await RunProcessAsync("postgres", pgCtl, "-D " + Quote(postgresDataDir) + " -l " + Quote(ServiceLogPath("postgres")) + " -o " + Quote("-h 127.0.0.1 -p 54329") + " start", repoRoot);
            }

            await WaitPortAsync("postgres", 54329, 45000);
            await RunProcessAsync("postgres", createdb, "-h 127.0.0.1 -p 54329 -U postgres immich", repoRoot, true);
            var databaseCheck = await RunProcessCaptureAsync("postgres", psql, "-h 127.0.0.1 -p 54329 -U postgres -d postgres -tAc " + Quote("SELECT 1 FROM pg_database WHERE datname='immich';"), repoRoot);
            if (!databaseCheck.Trim().Contains("1"))
            {
                throw new InvalidOperationException("PostgreSQL 已启动，但 immich 数据库没有创建成功。请查看 PostgreSQL 日志。");
            }
            await RunProcessAsync("postgres", psql, "-h 127.0.0.1 -p 54329 -U postgres -d immich -v ON_ERROR_STOP=1 -c " + Quote("CREATE EXTENSION IF NOT EXISTS vector;"), repoRoot);
        }

        private async Task StopPostgresAsync()
        {
            var pgCtl = Path.Combine(runtimeDir, "postgres", "bin", "pg_ctl.exe");
            if (File.Exists(pgCtl) && File.Exists(Path.Combine(postgresDataDir, "PG_VERSION")))
            {
                await RunProcessAsync("postgres", pgCtl, "-D " + Quote(postgresDataDir) + " stop -m fast", repoRoot, true);
            }
            if (await IsPortOpenAsync(54329)) await KillPortAsync("postgres", 54329);
        }

        private async Task StartRedisAsync()
        {
            var redis = Path.Combine(runtimeDir, "redis", "redis-server.exe");
            AssertFile(redis, "缺少内置 Redis");
            if (await IsPortOpenAsync(63790)) return;

            var arguments = string.Join(" ", new[]
            {
                "--bind 127.0.0.1",
                "--port 63790",
                "--dir ../data/redis",
            });
            StartTracked("redis", redis, arguments, Path.Combine(runtimeDir, "redis"));
            await WaitPortAsync("redis", 63790, 30000);
        }

        private async Task StopRedisAsync()
        {
            var cli = Path.Combine(runtimeDir, "redis", "redis-cli.exe");
            if (File.Exists(cli))
            {
                await RunProcessAsync("redis", cli, "-h 127.0.0.1 -p 63790 SHUTDOWN NOSAVE", repoRoot, true);
            }
            if (await IsPortOpenAsync(63790)) await KillPortAsync("redis", 63790);
            RemoveTracked("redis");
        }

        private async Task StartMachineLearningAsync()
        {
            if (await IsPortOpenAsync(3003)) return;
            var venvPython = Path.Combine(repoRoot, "machine-learning", ".venv", "Scripts", "python.exe");
            if (File.Exists(venvPython))
            {
                EnsureMachineLearningVenvConfig();
                StartTracked("ml", venvPython, "-m immich_ml --host 127.0.0.1 --port 3003", Path.Combine(repoRoot, "machine-learning"), MachineLearningEnvironment());
                await WaitPortAsync("ml", 3003, 120000);
                return;
            }
            var uv = Path.Combine(runtimeDir, "tools", "uv", "uv.exe");
            AssertFile(uv, "缺少内置 uv，请检查 runtime\\tools\\uv\\uv.exe");
            var bundledPython = GetBundledPython();
            var pythonArg = File.Exists(bundledPython) ? " --python " + Quote(bundledPython) : "";
            StartTracked("ml", uv, "run" + pythonArg + " --frozen --no-dev --extra cpu python -m immich_ml --host 127.0.0.1 --port 3003", Path.Combine(repoRoot, "machine-learning"), MachineLearningEnvironment());
            await WaitPortAsync("ml", 3003, 120000);
        }

        private Dictionary<string, string> MachineLearningEnvironment()
        {
            return new Dictionary<string, string>
            {
                { "IMMICH_HOST", "127.0.0.1" },
                { "IMMICH_PORT", "3003" },
                { "PORT", "3003" },
                { "MACHINE_LEARNING_HOST", "127.0.0.1" },
                { "MACHINE_LEARNING_PORT", "3003" },
            };
        }

        private string GetBundledPython()
        {
            var pythonRoot = Path.Combine(runtimeDir, "python");
            if (!Directory.Exists(pythonRoot)) return "";

            foreach (var dir in Directory.GetDirectories(pythonRoot, "cpython-3.12*").OrderByDescending(path => path))
            {
                var python = Path.Combine(dir, "python.exe");
                if (File.Exists(python)) return python;
            }

            return "";
        }

        private void EnsureMachineLearningVenvConfig()
        {
            var bundledPython = GetBundledPython();
            AssertFile(bundledPython, "Missing bundled Python runtime in runtime\\python");

            var cfg = Path.Combine(repoRoot, "machine-learning", ".venv", "pyvenv.cfg");
            var content = string.Join(Environment.NewLine, new[]
            {
                "home = " + Path.GetDirectoryName(bundledPython),
                "implementation = CPython",
                "uv = 0.11.11",
                "version_info = 3.12.13",
                "include-system-site-packages = false",
                "prompt = immich-ml",
                "",
            });
            File.WriteAllText(cfg, content, Encoding.UTF8);
        }

        private async Task StartServerAsync()
        {
            if (await IsPortOpenAsync(2283)) return;
            AppendLog("server", "[manager] preparing PostgreSQL" + Environment.NewLine);
            await StartPostgresAsync();
            AppendLog("server", "[manager] preparing Redis" + Environment.NewLine);
            await StartRedisAsync();
            AppendLog("server", "[manager] checking web build and core plugin" + Environment.NewLine);
            AssertFile(Path.Combine(buildDir, "www", "index.html"), "缺少 Web 构建产物 build\\www");
            EnsureCorePlugin();
            AppendLog("server", "[manager] starting Immich Server" + Environment.NewLine);
            var node = Path.Combine(runtimeDir, "node", "node-v22.20.0-win-x64", "node.exe");
            var pnpm = Path.Combine(runtimeDir, "tools", "pnpm", "package", "bin", "pnpm.cjs");
            AssertFile(node, "Missing bundled Node.js runtime in runtime\\node");
            AssertFile(pnpm, "Missing bundled pnpm runtime in runtime\\tools\\pnpm");
            StartTracked("server", node, Quote(pnpm) + " --filter immich start:dev", repoRoot);
            await WaitPortAsync("server", 2283, 120000);
        }

        private void EnsureCorePlugin()
        {
            var buildPluginDir = Path.Combine(buildDir, "corePlugin");
            var buildPluginDist = Path.Combine(buildPluginDir, "dist");
            var buildManifest = Path.Combine(buildPluginDir, "manifest.json");
            var buildWasm = Path.Combine(buildPluginDist, "plugin.wasm");
            if (File.Exists(buildManifest) && File.Exists(buildWasm)) return;

            var sourcePluginDir = Path.Combine(repoRoot, "plugins");
            var sourceManifest = Path.Combine(sourcePluginDir, "manifest.json");
            var sourceWasm = Path.Combine(sourcePluginDir, "dist", "plugin.wasm");
            AssertFile(sourceManifest, "缺少 core plugin manifest");
            AssertFile(sourceWasm, "缺少 core plugin wasm，请先构建 plugins\\dist\\plugin.wasm");

            Directory.CreateDirectory(buildPluginDist);
            File.Copy(sourceManifest, buildManifest, true);
            File.Copy(sourceWasm, buildWasm, true);
        }

        private void StartTracked(string componentId, string fileName, string arguments, string workingDirectory, Dictionary<string, string> environmentOverrides = null)
        {
            RemoveTracked(componentId);
            var startInfo = MakeStartInfo(fileName, arguments, workingDirectory, environmentOverrides);
            startInfo.RedirectStandardOutput = true;
            startInfo.RedirectStandardError = true;
            var process = new Process { StartInfo = startInfo, EnableRaisingEvents = true };
            process.OutputDataReceived += (sender, args) => { if (args.Data != null) AppendLog(componentId, args.Data + Environment.NewLine); };
            process.ErrorDataReceived += (sender, args) => { if (args.Data != null) AppendLog(componentId, args.Data + Environment.NewLine); };
            process.Exited += (sender, args) =>
            {
                AppendLog(componentId, "[manager] process exited" + Environment.NewLine);
                BeginInvoke(new Action(async () => await RefreshStatusAsync()));
            };
            process.Start();
            process.BeginOutputReadLine();
            process.BeginErrorReadLine();
            managedProcesses[componentId] = process;
            AppendLog(componentId, "[manager] started: " + fileName + " " + arguments + Environment.NewLine);
        }

        private async Task StopTrackedOrPortAsync(string componentId, int port)
        {
            RemoveTracked(componentId);
            if (await IsPortOpenAsync(port)) await KillPortAsync(componentId, port);
        }

        private void RemoveTracked(string componentId)
        {
            if (!managedProcesses.ContainsKey(componentId)) return;
            try
            {
                var process = managedProcesses[componentId];
                if (!process.HasExited) process.Kill();
                process.Dispose();
            }
            catch { }
            managedProcesses.Remove(componentId);
        }

        private ProcessStartInfo MakeStartInfo(string fileName, string arguments, string workingDirectory, Dictionary<string, string> environmentOverrides = null)
        {
            var startInfo = new ProcessStartInfo
            {
                FileName = fileName,
                Arguments = arguments,
                WorkingDirectory = workingDirectory,
                UseShellExecute = false,
                CreateNoWindow = true,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            };
            foreach (var pair in BuildEnvironment()) startInfo.EnvironmentVariables[pair.Key] = pair.Value;
            if (environmentOverrides != null)
            {
                foreach (var pair in environmentOverrides) startInfo.EnvironmentVariables[pair.Key] = pair.Value;
            }
            return startInfo;
        }

        private async Task RunProcessAsync(string componentId, string fileName, string arguments, string workingDirectory, bool ignoreFailure = false)
        {
            await Task.Run(() =>
            {
                var startInfo = MakeStartInfo(fileName, arguments, workingDirectory);
                using (var process = Process.Start(startInfo))
                {
                    var output = process.StandardOutput.ReadToEnd();
                    var error = process.StandardError.ReadToEnd();
                    process.WaitForExit();
                    if (!string.IsNullOrWhiteSpace(output)) AppendLog(componentId, output);
                    if (!string.IsNullOrWhiteSpace(error)) AppendLog(componentId, error);
                    if (process.ExitCode != 0 && !ignoreFailure)
                    {
                        throw new InvalidOperationException(fileName + " failed with exit code " + process.ExitCode + Environment.NewLine + error);
                    }
                }
            });
        }

        private async Task<string> RunProcessCaptureAsync(string componentId, string fileName, string arguments, string workingDirectory)
        {
            return await Task.Run(() =>
            {
                var startInfo = MakeStartInfo(fileName, arguments, workingDirectory);
                using (var process = Process.Start(startInfo))
                {
                    var output = process.StandardOutput.ReadToEnd();
                    var error = process.StandardError.ReadToEnd();
                    process.WaitForExit();
                    if (!string.IsNullOrWhiteSpace(output)) AppendLog(componentId, output);
                    if (!string.IsNullOrWhiteSpace(error)) AppendLog(componentId, error);
                    if (process.ExitCode != 0)
                    {
                        throw new InvalidOperationException(fileName + " failed with exit code " + process.ExitCode + Environment.NewLine + error);
                    }
                    return output;
                }
            });
        }

        private async Task<bool> IsPortOpenAsync(int port)
        {
            try
            {
                using (var client = new TcpClient())
                {
                    var connect = client.ConnectAsync("127.0.0.1", port);
                    var timeout = Task.Delay(500);
                    return await Task.WhenAny(connect, timeout) == connect && client.Connected;
                }
            }
            catch
            {
                return false;
            }
        }

        private async Task WaitPortAsync(string componentId, int port, int timeoutMs)
        {
            var deadline = DateTime.UtcNow.AddMilliseconds(timeoutMs);
            while (DateTime.UtcNow < deadline)
            {
                if (await IsPortOpenAsync(port)) return;
                await Task.Delay(500);
            }
            throw new TimeoutException(components[componentId].Name + " 启动超时: 127.0.0.1:" + port);
        }

        private async Task KillPortAsync(string componentId, int port)
        {
            await RunProcessAsync(componentId, "cmd.exe", "/c for /f \"tokens=5\" %a in ('netstat -ano ^| findstr :" + port + "') do taskkill /PID %a /T /F", repoRoot, true);
        }

        private void LoadLog(string componentId)
        {
            var text = new StringBuilder();
            AppendReadableLog(text, "管理器日志", LogPath(componentId));
            AppendReadableLog(text, "组件日志", ServiceLogPath(componentId));

            if (text.Length == 0)
            {
                logBox.Text = "暂无日志。";
                return;
            }
            var value = text.ToString();
            if (value.Length > 30000) value = value.Substring(value.Length - 30000);
            logBox.Text = value;
            logBox.SelectionStart = logBox.TextLength;
            logBox.ScrollToCaret();
        }

        private void AppendReadableLog(StringBuilder target, string title, string path)
        {
            if (!File.Exists(path)) return;
            target.AppendLine("========== " + title + ": " + Path.GetFileName(path) + " ==========");
            try
            {
                using (var stream = new FileStream(path, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
                using (var reader = new StreamReader(stream, Encoding.UTF8, true))
                {
                    target.AppendLine(reader.ReadToEnd());
                }
            }
            catch (IOException ex)
            {
                target.AppendLine("[日志文件正在被组件占用，暂时无法读取]");
                target.AppendLine(ex.Message);
            }
            catch (UnauthorizedAccessException ex)
            {
                target.AppendLine("[没有权限读取该日志文件]");
                target.AppendLine(ex.Message);
            }
            target.AppendLine();
        }

        private void AppendLog(string componentId, string text)
        {
            Directory.CreateDirectory(logsDir);
            var bytes = Encoding.UTF8.GetBytes(text);
            using (var stream = new FileStream(LogPath(componentId), FileMode.Append, FileAccess.Write, FileShare.ReadWrite | FileShare.Delete))
            {
                stream.Write(bytes, 0, bytes.Length);
            }
            if (componentId == selectedComponent)
            {
                BeginInvoke(new Action(() => LoadLog(componentId)));
            }
        }

        private string LogPath(string componentId)
        {
            return Path.Combine(logsDir, "manager-" + componentId + ".log");
        }

        private string ServiceLogPath(string componentId)
        {
            return Path.Combine(logsDir, componentId + "-service.log");
        }

        private static string Quote(string value)
        {
            return "\"" + value.Replace("\"", "\\\"") + "\"";
        }

        private static void AssertFile(string path, string message)
        {
            if (!File.Exists(path)) throw new FileNotFoundException(message, path);
        }
    }
}
