%% Generate Fig5_14 — Post-Restoration Voltages (all 36 scenarios)
%  Run this once in the MATLAB Command Window.
%  Reads restoration_results_full.csv and saves the figure directly.

T_rest = readtable('restoration_results_full.csv');

valid  = ~strcmp(T_rest.Verdict, 'ERROR');
T_v    = T_rest(valid, :);
lm_vals = unique(T_v.LoadMult);
clrs   = [0.18 0.42 0.78; 0.89 0.42 0.04; 0.13 0.63 0.30];

fig = figure('Visible','on','Position',[50 50 860 420]);

%% Left panel — Bus B4
subplot(1,2,1); hold on; box on; grid on;
for li = 1:numel(lm_vals)
    rows = T_v(T_v.LoadMult == lm_vals(li), :);
    plot(1:height(rows), rows.Vpost_B4_pu, 'o-', ...
        'Color', clrs(li,:), 'LineWidth', 1.4, 'MarkerSize', 5, ...
        'DisplayName', sprintf('LM = %.2f pu', lm_vals(li)));
end
yline(0.95, 'k--', 'LineWidth', 1.0, 'HandleVisibility','off');
yline(1.05, 'k--', 'LineWidth', 1.0, 'HandleVisibility','off');
text(18.5, 0.953, '0.95 pu', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
text(18.5, 1.047, '1.05 pu', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
xlabel('Scenario Index (1–36)', 'FontSize', 10);
ylabel('Post-Restoration Voltage (pu)', 'FontSize', 10);
title('Bus B4', 'FontSize', 11, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
ylim([0.935 1.065]); xlim([0 37]);
set(gca, 'FontSize', 9);

%% Right panel — Bus B5
subplot(1,2,2); hold on; box on; grid on;
for li = 1:numel(lm_vals)
    rows = T_v(T_v.LoadMult == lm_vals(li), :);
    plot(1:height(rows), rows.Vpost_B5_pu, 's-', ...
        'Color', clrs(li,:), 'LineWidth', 1.4, 'MarkerSize', 5, ...
        'DisplayName', sprintf('LM = %.2f pu', lm_vals(li)));
end
yline(0.95, 'k--', 'LineWidth', 1.0, 'HandleVisibility','off');
yline(1.05, 'k--', 'LineWidth', 1.0, 'HandleVisibility','off');
text(18.5, 0.953, '0.95 pu', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
text(18.5, 1.047, '1.05 pu', 'FontSize', 8, 'Color', [0.3 0.3 0.3]);
xlabel('Scenario Index (1–36)', 'FontSize', 10);
ylabel('Post-Restoration Voltage (pu)', 'FontSize', 10);
title('Bus B5 (SX-EW)', 'FontSize', 11, 'FontWeight', 'bold');
legend('Location', 'best', 'FontSize', 9);
ylim([0.935 1.065]); xlim([0 37]);
set(gca, 'FontSize', 9);

%% Title
n_pass = sum(strcmp(T_rest.Verdict, 'PASS'));
n_tot  = height(T_rest);
sgtitle(sprintf('Post-Restoration Voltages — %d/%d Scenarios PASS (all within 0.95–1.05 pu)', ...
    n_pass, n_tot), 'FontSize', 11, 'FontWeight', 'bold');

%% Save
out_path = fullfile('figures', 'ch5_results', 'Fig5_14_restoration_rms.png');
try
    exportgraphics(fig, out_path, 'Resolution', 300);
catch
    saveas(fig, out_path);
end
fprintf('Saved: %s\n', out_path);
close(fig);
