function REGEN_BW()
%% Regenerate the multi-line result figures in print-safe BLACK & WHITE.
%  - Per-class signatures (5.1/5.2): grayscale heatmaps.
%  - Fault waveforms (5.3-5.6): 4 buses drawn with distinct LINE STYLES so
%    they remain distinguishable when printed in black and white.
%  Reads only saved data (no simulation) -> runs headless.  Run from scripts/.
clc;
DATA = 'outputs_v2_topology';
OUT  = fullfile(DATA,'figures','bw'); if ~exist(OUT,'dir'); mkdir(OUT); end
WAVE = fullfile(DATA,'waveforms_v2');
dfile= fullfile(DATA,'fault_dataset_v2.mat');

signature_bw(dfile,'V',fullfile(OUT,'bw_Figure_5_1.png'));
signature_bw(dfile,'I',fullfile(OUT,'bw_Figure_5_2.png'));
fprintf('signatures done\n');

map={'SLG_B2','bw_Figure_5_3'; '3PH_B3','bw_Figure_5_4'; 'SLG_B4','bw_Figure_5_5'; '3PH_B5','bw_Figure_5_6'};
for k=1:size(map,1)
    W=load(fullfile(WAVE,['wave_' map{k,1} '.mat']));
    wave_bw(W, fullfile(OUT,[map{k,2} '.png']));
    fprintf('%s done\n', map{k,2});
end
fprintf('REGEN_BW COMPLETE\n');
end

function signature_bw(dfile,kind,fout)
    S=load(dfile); X=S.X; y=S.y; names=S.featNames;
    idx=find(startsWith(names,[kind '_']));
    M=zeros(13,numel(idx)); for c=0:12; M(c+1,:)=mean(X(y==c,idx),1); end
    ref=M(1,:); ref(abs(ref)<1e-9)=1e-9;
    if strcmpi(kind,'V'); H=100*(1-M./ref); ttl='Voltage sag relative to the healthy operating point'; cbtxt='Voltage sag (%)';
    else; H=M./ref; ttl='RMS current relative to the healthy operating point'; cbtxt='Current ratio (x healthy)'; end
    fig=figure('Visible','off','Position',[40 40 1180 650],'Color','w'); ax=axes(fig);
    imagesc(ax,H); colormap(ax,flipud(gray));      % darker = larger magnitude
    cb=colorbar(ax); cb.Label.String=cbtxt;
    lo=min(H(:)); hi=max(H(:)); if strcmpi(kind,'V')&&lo>0; lo=0; end; if hi<=lo; hi=lo+1; end; caxis(ax,[lo hi]);
    set(ax,'YTick',1:13,'YTickLabel',S.CLASS_NAMES,'XTick',1:numel(idx),'XTickLabel',names(idx),...
        'XTickLabelRotation',45,'FontSize',9,'TickLabelInterpreter','none','FontName','Times New Roman','Layer','top','Box','on');
    hold(ax,'on'); for x=[3.5 6.5 9.5]; xline(ax,x,'k-','LineWidth',0.7); end
    title(ax,ttl,'FontWeight','bold'); xlabel(ax,'Measured feature'); ylabel(ax,'Fault class');
    exportgraphics(fig,fout,'Resolution',300); close(fig);
end

function wave_bw(W,fout)
    Vf=W.Vf; If=W.If; Vpu=W.Vpu; VBAND=W.VBAND;
    Vfault_kV=min(Vf(:,2:4),[],2)/1000; Ia_A=If(:,2);
    fig=figure('Visible','off','Position',[40 40 1000 760],'Color','w');
    ax1=subplot(2,1,1);
    yyaxis(ax1,'left');  hV=plot(ax1,Vf(:,1),Vfault_kV,'-','Color','k','LineWidth',1.5); ax1.YColor='k';
    ylabel(ax1,'Minimum line-to-line RMS voltage (kV)');
    yyaxis(ax1,'right'); hI=plot(ax1,If(:,1),Ia_A,'--','Color',[0.35 0.35 0.35],'LineWidth',1.5); ax1.YColor=[0.35 0.35 0.35];
    ylabel(ax1,'Faulted-bus RMS I_A (A)');
    grid(ax1,'on'); box(ax1,'on'); xlabel(ax1,'Time (s)');
    legend(ax1,[hV hI],{'Minimum V_{LL,RMS} (solid)','I_{A,RMS} (dashed)'},'Location','best');
    if isfield(W,'predZone'); title(ax1,sprintf('Stage 1 - %s fault at %s (normal network, tie open) | RF predicted: %s',W.ftype,W.zone,W.predZone));
    else; title(ax1,sprintf('Stage 1 - %s fault at %s (normal network, tie open)',W.ftype,W.zone)); end

    ax2=subplot(2,1,2); hold(ax2,'on'); box(ax2,'on'); grid(ax2,'on');
    busn={'B2','B3','B4','B5'}; sty={'-','--',':','-.'}; gc=[0 0 0; 0.25 0.25 0.25; 0 0 0; 0.45 0.45 0.45]; lw=[1.5 1.6 2.0 1.7];
    hh=zeros(1,4);
    for b=1:4
        hh(b)=plot(ax2,Vpu.(busn{b})(:,1),Vpu.(busn{b})(:,2),sty{b},'Color',gc(b,:),'LineWidth',lw(b));
    end
    yline(ax2,VBAND(1),':','Color',[0.55 0.55 0.55]); yline(ax2,VBAND(2),':','Color',[0.55 0.55 0.55]); ylim(ax2,[0 1.15]);
    xlabel(ax2,'Time (s)'); ylabel(ax2,'Bus voltage (pu)');
    legend(ax2,hh,busn,'Location','eastoutside');
    title(ax2,sprintf('Stage 2 - after isolation (%s) + tie %s : %s',strjoin(W.brk,'+'),tern(W.tieClosed,'CLOSED','OPEN'),W.status),'Interpreter','none');
    exportgraphics(fig,fout,'Resolution',200); close(fig);
end
function s=tern(c,a,b); if c; s=a; else; s=b; end; end
